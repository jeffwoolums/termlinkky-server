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
        try:
            # Check if session already exists
            result = subprocess.run(
                ["tmux", "has-session", "-t", self.SESSION_NAME],
                capture_output=True,
                timeout=5
            )
            
            if result.returncode != 0:
                # Create new session with phone-friendly size
                print(f"Creating new tmux session: {self.SESSION_NAME}")
                subprocess.run([
                    "tmux", "new-session", "-d", "-s", self.SESSION_NAME,
                    "-x", "48", "-y", "30"
                ], timeout=5)
            else:
                print(f"Attaching to existing tmux session: {self.SESSION_NAME}")
            
            # Open PTY to tmux with phone-friendly size
            self._master_fd, slave_fd = pty.openpty()
            
            # Set PTY size to phone dimensions (48 cols x 30 rows)
            import struct
            import fcntl
            import termios
            winsize = struct.pack('HHHH', 30, 48, 0, 0)  # rows, cols, xpixel, ypixel
            fcntl.ioctl(self._master_fd, termios.TIOCSWINSZ, winsize)
            
            self._pid = os.fork()
            
            if self._pid == 0:
                # Child process
                os.close(self._master_fd)
                os.setsid()
                os.dup2(slave_fd, 0)
                os.dup2(slave_fd, 1)
                os.dup2(slave_fd, 2)
                os.close(slave_fd)
                # Set TERM so tmux knows terminal capabilities
                os.environ["TERM"] = "xterm-256color"
                os.execlp("tmux", "tmux", "attach-session", "-t", self.SESSION_NAME)
            else:
                # Parent process
                os.close(slave_fd)
                self._running = True
                self._read_task = asyncio.create_task(self._read_output())
                print(f"PTY started: master_fd={self._master_fd}, pid={self._pid}")
        except Exception as e:
            print(f"Error starting tmux session: {e}")
            self._running = False
            raise
    
    async def _read_output(self):
        """Read output and broadcast to all clients."""
        import errno
        print("PTY read loop started")
        idle_cycles = 0
        check_interval = 100  # Check child every ~5 seconds of idle
        
        while self._running:
            try:
                if not self._master_fd:
                    print("PTY master_fd is None, stopping read loop")
                    break
                
                # Short timeout so we can check for new clients etc
                r, _, _ = select.select([self._master_fd], [], [], 0.05)
                
                if r:
                    try:
                        data = os.read(self._master_fd, 4096)
                    except OSError as e:
                        if e.errno == errno.EIO:
                            # EIO is expected when PTY closes
                            print("PTY closed (EIO)")
                            break
                        raise
                    
                    if data:
                        text = data.decode("utf-8", errors="replace")
                        idle_cycles = 0  # Reset idle counter on data
                        
                        # Broadcast to all connected clients
                        dead_clients = []
                        for client in self._clients:
                            try:
                                await client.send_str(text)
                            except Exception as e:
                                print(f"Error sending to client: {e}")
                                dead_clients.append(client)
                        for dc in dead_clients:
                            if dc in self._clients:
                                self._clients.remove(dc)
                    else:
                        # Empty read but select said ready - rare but OK
                        idle_cycles += 1
                else:
                    # No data ready (select timeout) - completely normal for tmux
                    idle_cycles += 1
                
                # Only check child status periodically during idle
                if idle_cycles >= check_interval:
                    idle_cycles = 0
                    try:
                        pid, status = os.waitpid(self._pid, os.WNOHANG)
                        if pid != 0:
                            print(f"Child process exited with status {status}")
                            break
                    except ChildProcessError:
                        print("Child process no longer exists")
                        break
                
                await asyncio.sleep(0.01)
                
            except (OSError, BrokenPipeError) as e:
                print(f"PTY error: {e}")
                break
            except Exception as e:
                print(f"Unexpected error in read loop: {e}")
                import traceback
                traceback.print_exc()
                break
                
        print("PTY read loop ended")
        self._running = False
    
    async def write(self, data: str):
        """Write input to the shared terminal."""
        # Try PTY write first
        if self._master_fd and self._running:
            try:
                os.write(self._master_fd, data.encode("utf-8"))
                return
            except (OSError, BrokenPipeError) as e:
                print(f"PTY write error: {e}, attempting recovery...")
                self._running = False
        
        # Fallback: use tmux send-keys (more reliable but less interactive)
        try:
            # Escape special characters for tmux
            escaped = data.replace("'", "'\\''")
            subprocess.run(
                ["tmux", "send-keys", "-t", self.SESSION_NAME, "-l", data],
                timeout=2
            )
            print("Used tmux send-keys fallback")
        except Exception as e:
            print(f"tmux send-keys also failed: {e}")
        
        # Try to restart PTY connection in background
        if not self._running:
            try:
                await self._restart_tmux_connection()
            except Exception as e:
                print(f"Failed to restart PTY: {e}")
    
    async def _restart_tmux_connection(self):
        """Restart the PTY connection to tmux."""
        print("Restarting tmux connection...")
        # Clean up old connection
        if self._master_fd:
            try:
                os.close(self._master_fd)
            except:
                pass
        if self._pid:
            try:
                os.kill(self._pid, 9)
            except:
                pass
        # Start new connection
        await self._start_tmux_session()


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
                try:
                    await shared_session.write(msg.data)
                except Exception as e:
                    print(f"Error writing to terminal: {e}")
                    # Don't break - try to keep connection alive
                    # The write method should handle reconnection
            elif msg.type == aiohttp.WSMsgType.ERROR:
                print(f"WebSocket error: {ws.exception()}")
                break
    except Exception as e:
        print(f"Error in websocket handler: {e}")
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


async def info_handler(request):
    """Server info for autodiscovery and pairing."""
    hostname = subprocess.run(["hostname"], capture_output=True, text=True).stdout.strip()
    return web.json_response({
        "name": hostname,
        "fingerprint": get_certificate_fingerprint(),
        "pairingCode": get_pairing_code(),
        "version": "2.0.0"
    })


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


import time

# Dashboard and Session Management API

async def dashboard_handler(request):
    """Serve the session management dashboard."""
    dashboard_path = Path(__file__).parent / "dashboard.html"
    if dashboard_path.exists():
        return web.FileResponse(dashboard_path)
    return web.Response(text="Dashboard not found", status=404)

async def list_sessions_handler(request):
    """List all tmux sessions."""
    try:
        result = subprocess.run(
            ["tmux", "list-sessions", "-F", "#{session_name}|#{session_windows}|#{session_created}|#{session_attached}"],
            capture_output=True, text=True, timeout=5
        )
        sessions = []
        if result.returncode == 0:
            for line in result.stdout.strip().split('\n'):
                if line:
                    parts = line.split('|')
                    if len(parts) >= 4:
                        sessions.append({
                            "name": parts[0],
                            "windows": parts[1],
                            "created": parts[2],
                            "attached": parts[3] == "1"
                        })
        return web.json_response({"sessions": sessions})
    except Exception as e:
        return web.json_response({"error": str(e), "sessions": []})

async def create_session_handler(request):
    """Create a new tmux session."""
    try:
        data = await request.json()
        name = data.get("name", f"session-{int(time.time())}")
        name = "".join(c for c in name if c.isalnum() or c in "-_")[:32]
        subprocess.run(
            ["tmux", "new-session", "-d", "-s", name, "-x", "48", "-y", "30"],
            timeout=5
        )
        return web.json_response({"success": True, "name": name})
    except Exception as e:
        return web.json_response({"error": str(e)}, status=500)

async def delete_session_handler(request):
    """Kill a tmux session."""
    try:
        name = request.match_info.get("name")
        if not name:
            return web.json_response({"error": "No session name"}, status=400)
        subprocess.run(["tmux", "kill-session", "-t", name], timeout=5)
        return web.json_response({"success": True})
    except Exception as e:
        return web.json_response({"error": str(e)}, status=500)

def main():
    """Start the server."""
    # Check Tailscale
    tailscale_ip = get_tailscale_ip()
    if not tailscale_ip:
        print("\n⚠️  Warning: Tailscale not connected")
        print("TermLinkky works best over Tailscale for secure remote access.")
        print("Install from: https://tailscale.com/download\n")
    
    # Bind to all interfaces for both local and Tailscale access
    host = "0.0.0.0"
    
    generate_certificate()
    print_banner()
    
    ssl_ctx = ssl.create_default_context(ssl.Purpose.CLIENT_AUTH)
    ssl_ctx.load_cert_chain(str(CERT_FILE), str(KEY_FILE))
    
    app = web.Application()
    app.router.add_get("/", index_handler)
    app.router.add_get("/viewer", viewer_handler)
    app.router.add_get("/dashboard", dashboard_handler)  # Session manager UI
    app.router.add_get("/terminal", websocket_handler)  # Shared tmux session
    app.router.add_get("/terminal/private", websocket_private_handler)  # Private session
    app.router.add_get("/health", health_handler)
    app.router.add_get("/info", info_handler)  # Autodiscovery endpoint
    # Session management API
    app.router.add_get("/api/sessions", list_sessions_handler)
    app.router.add_post("/api/sessions", create_session_handler)
    app.router.add_delete("/api/sessions/{name}", delete_session_handler)
    
    # Start Bonjour/Zeroconf advertising
    zeroconf_instance = None
    service_info = None
    try:
        from zeroconf import Zeroconf, ServiceInfo
        import socket
        
        hostname = socket.gethostname()
        local_ip = socket.gethostbyname(hostname)
        
        service_info = ServiceInfo(
            "_termlinkky._tcp.local.",
            f"{hostname}._termlinkky._tcp.local.",
            addresses=[socket.inet_aton(local_ip)],
            port=PORT,
            properties={
                "version": "2.0.0",
                "pairing": get_pairing_code()
            },
            server=f"{hostname}.local."
        )
        
        zeroconf_instance = Zeroconf()
        zeroconf_instance.register_service(service_info)
        print(f"📡 Bonjour: Advertising as {hostname}._termlinkky._tcp.local.")
    except ImportError:
        print("📡 Bonjour: zeroconf not installed (pip install zeroconf)")
    except Exception as e:
        print(f"📡 Bonjour: Failed to advertise - {e}")
    
    print(f"Starting server on https://{host}:{PORT}")
    
    try:
        web.run_app(app, host=host, port=PORT, ssl_context=ssl_ctx)
    finally:
        if zeroconf_instance and service_info:
            zeroconf_instance.unregister_service(service_info)
            zeroconf_instance.close()


if __name__ == "__main__":
    main()

