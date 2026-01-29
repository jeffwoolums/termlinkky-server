#!/usr/bin/env python3
"""
TermLinkky Server - Mac/Windows/Linux companion for TermLinkky mobile app.
Provides secure WebSocket terminal access over Tailscale.

Requirements:
- Tailscale installed and connected
- Python 3.9+
"""

import asyncio
import os
import pty
import select
import signal
import ssl
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

PORT = 8443
CERT_DIR = Path(__file__).parent / "certs"
CERT_FILE = CERT_DIR / "server.crt"
KEY_FILE = CERT_DIR / "server.key"


def get_tailscale_ip() -> str:
    """Get Tailscale IP address. Returns None if not connected."""
    try:
        result = subprocess.run(
            ["tailscale", "ip", "-4"],
            capture_output=True, text=True, timeout=5
        )
        if result.returncode == 0:
            return result.stdout.strip().split('\n')[0]
    except (subprocess.TimeoutExpired, FileNotFoundError):
        pass
    return None


def get_tailscale_status() -> dict:
    """Get Tailscale connection status."""
    try:
        result = subprocess.run(
            ["tailscale", "status", "--json"],
            capture_output=True, text=True, timeout=5
        )
        if result.returncode == 0:
            import json
            return json.loads(result.stdout)
    except:
        pass
    return None


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
        "-subj", f"/CN={hostname}/O=TermLinkky"
    ], check=True)


class SharedTerminalSession:
    """Manages a shared tmux terminal session that multiple clients can connect to."""
    
    SESSION_NAME = "termlinkky"
    _instance = None
    _clients = []
    _master_fd = None
    _pid = None
    _running = False
    _read_task = None
    
    @classmethod
    def get_instance(cls):
        if cls._instance is None:
            cls._instance = cls()
        return cls._instance
    
    def __init__(self):
        pass
    
    async def add_client(self, ws: web.WebSocketResponse):
        """Add a client to the shared session."""
        self._clients.append(ws)
        
        # Start session if not running
        if not self._running:
            await self._start_tmux_session()
        
        # Send current tmux buffer to new client
        try:
            result = subprocess.run(
                ["tmux", "capture-pane", "-t", self.SESSION_NAME, "-p", "-S", "-1000"],
                capture_output=True, text=True, timeout=2
            )
            if result.returncode == 0 and result.stdout:
                await ws.send_str(result.stdout)
        except:
            pass
    
    def remove_client(self, ws: web.WebSocketResponse):
        """Remove a client from the session."""
        if ws in self._clients:
            self._clients.remove(ws)
    
    async def _start_tmux_session(self):
        """Start or attach to a tmux session."""
        # Check if session already exists
        result = subprocess.run(
            ["tmux", "has-session", "-t", self.SESSION_NAME],
            capture_output=True
        )
        
        if result.returncode != 0:
            # Create new session
            subprocess.run([
                "tmux", "new-session", "-d", "-s", self.SESSION_NAME,
                "-x", "120", "-y", "40"
            ])
        
        # Open PTY to tmux
        self._master_fd, slave_fd = pty.openpty()
        self._pid = os.fork()
        
        if self._pid == 0:
            os.close(self._master_fd)
            os.setsid()
            os.dup2(slave_fd, 0)
            os.dup2(slave_fd, 1)
            os.dup2(slave_fd, 2)
            os.close(slave_fd)
            os.execlp("tmux", "tmux", "attach-session", "-t", self.SESSION_NAME)
        else:
            os.close(slave_fd)
            self._running = True
            self._read_task = asyncio.create_task(self._read_output())
    
    async def _read_output(self):
        """Read output and broadcast to all clients."""
        while self._running:
            try:
                r, _, _ = select.select([self._master_fd], [], [], 0.1)
                if r:
                    data = os.read(self._master_fd, 4096)
                    if data:
                        text = data.decode("utf-8", errors="replace")
                        # Broadcast to all connected clients
                        dead_clients = []
                        for client in self._clients:
                            try:
                                await client.send_str(text)
                            except:
                                dead_clients.append(client)
                        for dc in dead_clients:
                            self._clients.remove(dc)
                await asyncio.sleep(0.01)
            except (OSError, BrokenPipeError):
                break
        self._running = False
    
    async def write(self, data: str):
        """Write input to the shared terminal."""
        if self._master_fd and self._running:
            os.write(self._master_fd, data.encode("utf-8"))


class TerminalSession:
    """Manages a PTY terminal session (legacy non-shared mode)."""
    
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
    """Handle WebSocket connections for terminal access (shared session via tmux)."""
    ws = web.WebSocketResponse()
    await ws.prepare(request)
    print(f"✓ Client connected: {request.remote}")
    
    # Use shared tmux session
    shared_session = SharedTerminalSession.get_instance()
    try:
        await shared_session.add_client(ws)
        async for msg in ws:
            if msg.type == aiohttp.WSMsgType.TEXT:
                await shared_session.write(msg.data)
            elif msg.type == aiohttp.WSMsgType.ERROR:
                break
    finally:
        shared_session.remove_client(ws)
        print(f"✗ Client disconnected: {request.remote}")
    return ws


async def websocket_private_handler(request):
    """Handle WebSocket connections for private terminal sessions."""
    ws = web.WebSocketResponse()
    await ws.prepare(request)
    print(f"✓ Private client connected: {request.remote}")
    
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
        print(f"✗ Private client disconnected: {request.remote}")
    return ws


async def health_handler(request):
    """Health check endpoint."""
    return web.json_response({"status": "ok", "service": "termlinkky"})


async def viewer_handler(request):
    """Serve the web-based terminal viewer."""
    viewer_path = Path(__file__).parent / "viewer.html"
    if viewer_path.exists():
        return web.FileResponse(viewer_path)
    return web.Response(text="Viewer not found", status=404)


async def index_handler(request):
    """Redirect root to viewer."""
    return web.HTTPFound('/viewer')


def print_banner():
    """Print startup banner with pairing info."""
    tailscale_ip = get_tailscale_ip()
    pairing_code = get_pairing_code()
    
    print("\n" + "=" * 55)
    print("  TermLinkky Server")
    print("=" * 55)
    
    if tailscale_ip:
        print(f"\n  ✓ Tailscale connected")
        print(f"\n  📍 Address: {tailscale_ip}:{PORT}")
        print(f"\n  🔐 Pairing Code: {pairing_code}")
        print(f"\n  📺 Web Viewer: https://{tailscale_ip}:{PORT}/viewer")
        print("\n  📱 All clients share ONE tmux session!")
        print("     Run 'tmux attach -t termlinkky' locally to join.")
    else:
        print("\n  ⚠️  Tailscale not connected!")
        print("\n  TermLinkky requires Tailscale for remote access.")
        print("  Install: https://tailscale.com/download")
        print("\n  After installing, run: tailscale up")
    
    print("\n" + "=" * 55 + "\n")


def main():
    """Start the server."""
    # Check Tailscale
    tailscale_ip = get_tailscale_ip()
    if not tailscale_ip:
        print("\n⚠️  Warning: Tailscale not connected")
        print("TermLinkky works best over Tailscale for secure remote access.")
        print("Install from: https://tailscale.com/download\n")
        # Fall back to all interfaces for local testing
        host = "0.0.0.0"
    else:
        # Bind only to Tailscale interface for security
        host = tailscale_ip
    
    generate_certificate()
    print_banner()
    
    ssl_ctx = ssl.create_default_context(ssl.Purpose.CLIENT_AUTH)
    ssl_ctx.load_cert_chain(str(CERT_FILE), str(KEY_FILE))
    
    app = web.Application()
    app.router.add_get("/", index_handler)
    app.router.add_get("/viewer", viewer_handler)
    app.router.add_get("/terminal", websocket_handler)  # Shared tmux session
    app.router.add_get("/terminal/private", websocket_private_handler)  # Private session
    app.router.add_get("/health", health_handler)
    
    print(f"Starting server on https://{host}:{PORT}")
    web.run_app(app, host=host, port=PORT, ssl_context=ssl_ctx)


if __name__ == "__main__":
    main()
