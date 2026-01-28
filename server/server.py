#!/usr/bin/env python3
"""
TermLinky Server - Mac companion for the TermLinky iOS app.
Provides secure WebSocket terminal access with certificate pinning.
"""

import asyncio
import os
import pty
import select
import signal
import ssl
import struct
import subprocess
import sys
from pathlib import Path

try:
    from aiohttp import web
    import aiohttp
except ImportError:
    print("Installing aiohttp...")
    subprocess.check_call([sys.executable, "-m", "pip", "install", "aiohttp"])
    from aiohttp import web
    import aiohttp

HOST = "0.0.0.0"
PORT = 8443
CERT_DIR = Path(__file__).parent / "certs"
CERT_FILE = CERT_DIR / "server.crt"
KEY_FILE = CERT_DIR / "server.key"


def get_certificate_fingerprint() -> str:
    """Calculate SHA-256 fingerprint of the server certificate."""
    if not CERT_FILE.exists():
        return ""
    result = subprocess.run(
        ["openssl", "x509", "-in", str(CERT_FILE), "-noout", "-fingerprint", "-sha256"],
        capture_output=True, text=True
    )
    if result.returncode == 0 and "=" in result.stdout:
        return result.stdout.strip().split("=")[1].lower()
    return ""


def get_pairing_code() -> str:
    """Generate 6-digit pairing code from certificate fingerprint."""
    fingerprint = get_certificate_fingerprint().replace(":", "")
    if not fingerprint:
        return "000000"
    return f"{int(fingerprint[:6], 16) % 1000000:06d}"


def generate_certificate():
    """Generate self-signed certificate if it doesn't exist."""
    if CERT_FILE.exists() and KEY_FILE.exists():
        return
    CERT_DIR.mkdir(parents=True, exist_ok=True)
    hostname = subprocess.run(["hostname"], capture_output=True, text=True).stdout.strip()
    print("Generating self-signed certificate...")
    subprocess.run([
        "openssl", "req", "-x509", "-newkey", "rsa:4096",
        "-keyout", str(KEY_FILE), "-out", str(CERT_FILE),
        "-days", "3650", "-nodes",
        "-subj", f"/CN={hostname}/O=TermLinky"
    ], check=True)


class TerminalSession:
    """Manages a PTY terminal session."""
    
    def __init__(self, ws: web.WebSocketResponse):
        self.ws = ws
        self.master_fd = None
        self.pid = None
        self.running = False
    
    async def start(self):
        """Start the terminal session."""
        shell = os.environ.get("SHELL", "/bin/bash")
        self.master_fd, slave_fd = pty.openpty()
        self.pid = os.fork()
        
        if self.pid == 0:
            os.close(self.master_fd)
            os.setsid()
            os.dup2(slave_fd, 0)
            os.dup2(slave_fd, 1)
            os.dup2(slave_fd, 2)
            os.close(slave_fd)
            os.execvp(shell, [shell])
        else:
            os.close(slave_fd)
            self.running = True
            asyncio.create_task(self._read_output())
    
    async def _read_output(self):
        """Read output from PTY and send to WebSocket."""
        while self.running:
            try:
                r, _, _ = select.select([self.master_fd], [], [], 0.1)
                if r:
                    data = os.read(self.master_fd, 4096)
                    if data:
                        await self.ws.send_str(data.decode("utf-8", errors="replace"))
                    else:
                        break
                await asyncio.sleep(0.01)
            except (OSError, BrokenPipeError):
                break
        self.running = False
    
    async def write(self, data: str):
        """Write input to the terminal."""
        if self.master_fd and self.running:
            os.write(self.master_fd, data.encode("utf-8"))
    
    def stop(self):
        """Stop the terminal session."""
        self.running = False
        if self.master_fd:
            try:
                os.close(self.master_fd)
            except OSError:
                pass
        if self.pid:
            try:
                os.kill(self.pid, signal.SIGTERM)
            except OSError:
                pass


async def websocket_handler(request):
    """Handle WebSocket connections for terminal access."""
    ws = web.WebSocketResponse()
    await ws.prepare(request)
    print(f"✓ Client connected: {request.remote}")
    
    session = TerminalSession(ws)
    try:
        await session.start()
        async for msg in ws:
            if msg.type == aiohttp.WSMsgType.TEXT:
                await session.write(msg.data)
            elif msg.type == aiohttp.WSMsgType.ERROR:
                break
    finally:
        session.stop()
        print(f"✗ Client disconnected: {request.remote}")
    return ws


async def health_handler(request):
    """Health check endpoint."""
    return web.json_response({"status": "ok", "service": "termlinky"})


def get_local_ip():
    """Get local IP address."""
    import socket
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except Exception:
        return "127.0.0.1"


def print_banner():
    """Print startup banner with pairing info."""
    local_ip = get_local_ip()
    pairing_code = get_pairing_code()
    
    print("\n" + "=" * 50)
    print("  TermLinky Server")
    print("=" * 50)
    print(f"\n  📍 Address: {local_ip}:{PORT}")
    print(f"\n  🔐 Pairing Code: {pairing_code}")
    print("\n  Enter this code in the iOS app to pair.")
    print("=" * 50 + "\n")


def main():
    """Start the server."""
    generate_certificate()
    print_banner()
    
    ssl_ctx = ssl.create_default_context(ssl.Purpose.CLIENT_AUTH)
    ssl_ctx.load_cert_chain(str(CERT_FILE), str(KEY_FILE))
    
    app = web.Application()
    app.router.add_get("/terminal", websocket_handler)
    app.router.add_get("/health", health_handler)
    
    print(f"Starting server on https://{HOST}:{PORT}")
    web.run_app(app, host=HOST, port=PORT, ssl_context=ssl_ctx)


if __name__ == "__main__":
    main()
