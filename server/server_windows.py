#!/usr/bin/env python3
"""
TermLinkky Server for Windows
Uses winpty for terminal emulation on Windows.
"""

import asyncio
import os
import ssl
import subprocess
import sys
from pathlib import Path

# Check for Windows
if sys.platform != 'win32':
    print("This script is for Windows. Use server.py on Mac/Linux.")
    sys.exit(1)

try:
    from aiohttp import web
    import aiohttp
except ImportError:
    print("Installing aiohttp...")
    subprocess.check_call([sys.executable, "-m", "pip", "install", "aiohttp"])
    from aiohttp import web
    import aiohttp

try:
    import winpty
except ImportError:
    print("Installing pywinpty...")
    subprocess.check_call([sys.executable, "-m", "pip", "install", "pywinpty"])
    import winpty

PORT = 8443
CERT_DIR = Path(__file__).parent / "certs"
CERT_FILE = CERT_DIR / "server.crt"
KEY_FILE = CERT_DIR / "server.key"


def get_tailscale_ip() -> str:
    """Get Tailscale IP address on Windows."""
    try:
        result = subprocess.run(
            ["tailscale", "ip", "-4"],
            capture_output=True, text=True, timeout=5, shell=True
        )
        if result.returncode == 0:
            return result.stdout.strip().split('\n')[0]
    except:
        pass
    return None


def get_certificate_fingerprint() -> str:
    """Calculate SHA-256 fingerprint of the server certificate."""
    if not CERT_FILE.exists():
        return ""
    try:
        result = subprocess.run(
            ["openssl", "x509", "-in", str(CERT_FILE), "-noout", "-fingerprint", "-sha256"],
            capture_output=True, text=True, shell=True
        )
        if result.returncode == 0 and "=" in result.stdout:
            return result.stdout.strip().split("=")[1].lower()
    except:
        pass
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
    hostname = os.environ.get('COMPUTERNAME', 'localhost')
    
    print("Generating self-signed certificate...")
    subprocess.run([
        "openssl", "req", "-x509", "-newkey", "rsa:4096",
        "-keyout", str(KEY_FILE), "-out", str(CERT_FILE),
        "-days", "3650", "-nodes",
        "-subj", f"/CN={hostname}/O=TermLinkky"
    ], check=True, shell=True)


class WindowsTerminalSession:
    """Manages a Windows terminal session using winpty."""
    
    def __init__(self, ws: web.WebSocketResponse):
        self.ws = ws
        self.pty = None
        self.running = False
    
    async def start(self):
        """Start the terminal session."""
        # Get PowerShell or cmd
        shell = os.environ.get('COMSPEC', 'cmd.exe')
        if os.path.exists(r'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe'):
            shell = 'powershell.exe'
        
        self.pty = winpty.PtyProcess.spawn(shell)
        self.running = True
        asyncio.create_task(self._read_output())
    
    async def _read_output(self):
        """Read output from PTY and send to WebSocket."""
        while self.running:
            try:
                if self.pty.isalive():
                    data = self.pty.read(4096)
                    if data:
                        await self.ws.send_str(data)
                await asyncio.sleep(0.01)
            except Exception:
                break
        self.running = False
    
    async def write(self, data: str):
        """Write input to the terminal."""
        if self.pty and self.running:
            self.pty.write(data)
    
    def stop(self):
        """Stop the terminal session."""
        self.running = False
        if self.pty:
            try:
                self.pty.close()
            except:
                pass


async def websocket_handler(request):
    """Handle WebSocket connections for terminal access."""
    ws = web.WebSocketResponse()
    await ws.prepare(request)
    print(f"✓ Client connected: {request.remote}")
    
    session = WindowsTerminalSession(ws)
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
    return web.json_response({"status": "ok", "service": "termlinkky", "platform": "windows"})


def print_banner():
    """Print startup banner with pairing info."""
    tailscale_ip = get_tailscale_ip()
    pairing_code = get_pairing_code()
    
    print("\n" + "=" * 55)
    print("  TermLinkky Server (Windows)")
    print("=" * 55)
    
    if tailscale_ip:
        print(f"\n  ✓ Tailscale connected")
        print(f"\n  Address: {tailscale_ip}:{PORT}")
        print(f"\n  Pairing Code: {pairing_code}")
        print("\n  Enter this address and code in the TermLinkky app.")
    else:
        print("\n  ⚠ Tailscale not connected!")
        print("\n  Install Tailscale from: https://tailscale.com/download")
    
    print("\n" + "=" * 55 + "\n")


def main():
    """Start the server."""
    tailscale_ip = get_tailscale_ip()
    host = tailscale_ip if tailscale_ip else "0.0.0.0"
    
    generate_certificate()
    print_banner()
    
    ssl_ctx = ssl.create_default_context(ssl.Purpose.CLIENT_AUTH)
    ssl_ctx.load_cert_chain(str(CERT_FILE), str(KEY_FILE))
    
    app = web.Application()
    app.router.add_get("/terminal", websocket_handler)
    app.router.add_get("/health", health_handler)
    
    print(f"Starting server on https://{host}:{PORT}")
    web.run_app(app, host=host, port=PORT, ssl_context=ssl_ctx)


if __name__ == "__main__":
    main()
