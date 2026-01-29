# TermLinkky Documentation

> **Your AI travels with you** — Phone has the intelligence, works on any server.

## Table of Contents
1. [Overview](#overview)
2. [Quick Start](#quick-start)
3. [Server Setup](#server-setup)
4. [Mobile App Guide](#mobile-app-guide)
5. [Features](#features)
6. [Troubleshooting](#troubleshooting)
7. [Architecture](#architecture)

---

## Overview

TermLinkky is a remote terminal platform with AI assistance. It lets you control your Mac from your iPhone over Tailscale with two modes:

| Mode | Description | Use Case |
|------|-------------|----------|
| **Local AI** | AI runs on your phone, sends commands to dumb servers | SSH into any server, AI helps you |
| **Server AI** | Watch/control AI sessions (Claude Code) running on Mac | Monitor coding agents remotely |

### Key Concepts

- **Shared Terminal**: All connected clients share ONE tmux session on the server
- **Secure by Default**: TLS encryption + certificate pinning + Tailscale isolation
- **Real Terminals**: Uses actual Terminal.app on Mac, not web replicas

---

## Quick Start

### 1. Set Up Tailscale (Both Devices)

```bash
# Mac
brew install tailscale
tailscale up

# iPhone
# Install Tailscale from App Store, sign in
```

### 2. Start the Server (Mac)

```bash
cd ~/developer/TermLinkky/server
python3 server.py
```

You'll see:
```
=========================================================
  TermLinkky Server
=========================================================

  ✓ Tailscale connected

  📍 Address: 100.70.5.93:8443

  🔐 Pairing Code: 730559

  📺 Web Viewer: https://100.70.5.93:8443/viewer

  📱 All clients share ONE tmux session!
     Run 'tmux attach -t termlinkky' locally to join.

=========================================================
```

### 3. Pair Your iPhone

1. Open TermLinkky app
2. Go to **Devices** tab
3. Tap **Pair Device**
4. Enter the server's IP and pairing code
5. Done!

---

## Server Setup

### Requirements

- macOS, Linux, or Windows
- Python 3.9+
- Tailscale installed and connected
- tmux (for shared sessions)

### Installation

```bash
# Clone or navigate to server directory
cd ~/developer/TermLinkky/server

# Install dependencies (auto-installs if missing)
pip3 install aiohttp

# Run server
python3 server.py
```

### Server Endpoints

| Endpoint | Type | Description |
|----------|------|-------------|
| `/terminal` | WebSocket | Shared tmux session (all clients see same terminal) |
| `/terminal/private` | WebSocket | Private shell session (isolated per client) |
| `/viewer` | HTTP | Web-based terminal viewer |
| `/health` | HTTP | Health check (`{"status": "ok"}`) |

### Configuration

The server runs on port **8443** by default with auto-generated TLS certificates.

| File | Location | Purpose |
|------|----------|---------|
| Certificate | `server/certs/server.crt` | TLS certificate |
| Private Key | `server/certs/server.key` | TLS private key |

**Security Notes:**
- Server binds to Tailscale IP only (not 0.0.0.0)
- Certificate fingerprint is used for pairing verification
- 6-digit pairing code derived from certificate hash

### Running as a Service (macOS)

```bash
# Install as launchd service
./install_service.sh

# Or run manually in background
nohup python3 server.py > server.log 2>&1 &
```

### tmux Session

The server creates a shared tmux session named `termlinkky`. You can:

```bash
# Attach from Mac (see what phone users see)
tmux attach -t termlinkky

# Detach (Ctrl+B, then D)

# List sessions
tmux ls
```

---

## Mobile App Guide

### Navigation

| Tab | Purpose |
|-----|---------|
| **Terminal** | Shared terminal with your Mac |
| **Local AI** | On-device AI assistant (requires API key) |
| **Server AI** | Monitor Claude Code/Aider sessions on Mac |
| **Devices** | Manage paired servers |
| **Settings** | Font size, quick commands, etc. |

### Terminal Screen

**Quick Keys Bar** (when connected):
- `⏎` Enter
- `⇥` Tab  
- `↑↓←→` Arrow keys
- `Esc` Escape
- `Ctrl` Opens Ctrl+key menu
- `^C` Cancel (Ctrl+C)
- `^D` EOF (Ctrl+D)
- `^Z` Suspend
- `^L` Clear screen

**AI Assistant** (floating button):
- Tap to open AI overlay
- Describe what you want to do
- AI suggests commands you can run with one tap

### Local AI Mode

Uses Claude or OpenAI API running on your phone:

1. Go to **Settings** → **AI Configuration**
2. Enter your API key (Claude or OpenAI)
3. Return to **Local AI** tab
4. Ask questions like:
   - "How do I find large files?"
   - "Show me running docker containers"
   - "Set up a Python virtual environment"

AI sees your recent terminal output for context.

### Server AI Mode

Monitor AI coding sessions running on your Mac:

1. Start an AI session on Mac:
   ```bash
   tmux new -s claude
   claude  # or aider, codex, etc.
   ```
2. Open **Server AI** tab on phone
3. See list of AI sessions
4. Tap to view/interact

### Quick Commands

Customize frequently-used commands:

1. Go to **Settings** → **Quick Commands**
2. Tap **+ Add Command**
3. Categories:
   - System (ls, pwd, etc.)
   - Git (status, pull, push, etc.)
   - Docker (ps, logs, etc.)
   - Development (npm, python, etc.)
   - Custom (your own)

Access via grid icon in terminal toolbar.

---

## Features

### Connection Features

| Feature | Description |
|---------|-------------|
| **Auto-discovery** | Scans network for TermLinkky servers |
| **Certificate Pinning** | Prevents MITM attacks |
| **Auto-reconnect** | Automatically reconnects on disconnect (up to 3 attempts) |
| **Connection Timeout** | 15s WebSocket, 10s pairing |

### Terminal Features

| Feature | Description |
|---------|-------------|
| **ANSI Colors** | Full color support (16 + 256 colors) |
| **Unicode** | Emoji and special characters |
| **Scrollback** | 1000 lines of history |
| **Quick Keys** | Special keys (arrows, ctrl, etc.) |

### AI Features

| Feature | Description |
|---------|-------------|
| **Context Awareness** | AI sees recent terminal output |
| **Command Suggestions** | Run AI suggestions with one tap |
| **Multiple Providers** | Claude or OpenAI |
| **BYOK** | Bring Your Own API Key |

---

## Troubleshooting

### Can't connect to server

1. **Check Tailscale**: Both devices must be on same Tailscale network
   ```bash
   tailscale status
   ```

2. **Check server is running**:
   ```bash
   curl -k https://100.x.x.x:8443/health
   # Should return: {"status": "ok", "service": "termlinkky"}
   ```

3. **Check firewall**: Port 8443 must be accessible over Tailscale

### Pairing code doesn't work

- Pairing code is derived from server certificate
- If you regenerated certs, code changed
- Delete old device from app, re-pair

### Terminal shows garbled output

- Some programs output escape sequences we don't handle
- Try: `export TERM=xterm-256color`
- Or: `reset` to clear terminal state

### AI not responding

1. Check API key is set in Settings
2. Check internet connection (phone needs internet for Claude/OpenAI)
3. Try regenerating API key at provider

### App crashes on launch

Recent fixes (Jan 2026):
- Added timeouts to all network operations
- Added null checks on API responses
- Fixed race condition in AI overlay

If still crashing:
1. Delete and reinstall app
2. Check for TestFlight update
3. Report issue with device/iOS version

---

## Architecture

### Components

```
┌─────────────────────────────────────────────────────────┐
│                      iPhone                              │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐     │
│  │  Terminal   │  │  Local AI   │  │ Server AI   │     │
│  │   Screen    │  │   Screen    │  │   Screen    │     │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘     │
│         │                │                │             │
│         └────────────────┼────────────────┘             │
│                          │                              │
│  ┌───────────────────────┴───────────────────────────┐ │
│  │              Connection Manager                    │ │
│  │  • WebSocket client                               │ │
│  │  • Certificate pinning                            │ │
│  │  • Auto-reconnect                                 │ │
│  └───────────────────────┬───────────────────────────┘ │
└──────────────────────────┼──────────────────────────────┘
                           │ WSS (TLS over Tailscale)
┌──────────────────────────┼──────────────────────────────┐
│                          │                Mac            │
│  ┌───────────────────────┴───────────────────────────┐ │
│  │              TermLinkky Server                     │ │
│  │  • aiohttp WebSocket server                       │ │
│  │  • TLS with self-signed cert                      │ │
│  │  • Binds to Tailscale IP only                     │ │
│  └───────────────────────┬───────────────────────────┘ │
│                          │                              │
│  ┌───────────────────────┴───────────────────────────┐ │
│  │           Shared Terminal Session                  │ │
│  │  • tmux session "termlinkky"                      │ │
│  │  • PTY for real terminal I/O                      │ │
│  │  • All clients share same view                    │ │
│  └───────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────┘
```

### Security Model

1. **Network Isolation**: Tailscale provides encrypted mesh network
2. **TLS Encryption**: All WebSocket traffic encrypted
3. **Certificate Pinning**: App verifies server certificate fingerprint
4. **Pairing Code**: 6-digit code confirms certificate match
5. **No Cloud**: Direct device-to-device, nothing goes through servers

### Data Flow

```
[User types on phone]
        │
        ▼
[WebSocket sends text]
        │
        ▼ (encrypted)
[Server receives]
        │
