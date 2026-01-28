# TermLinkky

Remote terminal access for developers. Connect your phone to your workstation securely over Tailscale.

## Requirements

- **Tailscale** - Required for secure remote access ([install](https://tailscale.com/download))
- Python 3.9+ (server)
- iOS 14+ / Android 8+ (client)

## How It Works

```
Your Phone                           Your Workstation
┌──────────────┐                    ┌──────────────┐
│  TermLinkky   │◄──────────────────►│  TermLinkky   │
│  App         │   Tailscale VPN    │  Server      │
│              │   (100.x.x.x)      │              │
│  iOS/Android │   + Cert Pinning   │  Mac/Win/Lin │
└──────────────┘                    └──────────────┘
```

1. **Tailscale** creates encrypted tunnel between devices
2. **Server** binds only to Tailscale IP (not exposed to internet)
3. **Certificate pinning** verifies you're connecting to YOUR machine
4. **Pairing code** ensures initial setup is secure

## Quick Start

### 1. Install Tailscale (both devices)

```bash
# macOS
brew install tailscale

# Or download from https://tailscale.com/download
```

Then connect:
```bash
tailscale up
```

### 2. Start the Server

```bash
cd server
pip3 install aiohttp
python3 server.py
```

You'll see:
```
==================================================
  TermLinkky Server
==================================================

  ✓ Tailscale connected

  📍 Address: 100.x.x.x:8443

  🔐 Pairing Code: 123456

  Enter this address and code in the TermLinkky app.
==================================================
```

### 3. Pair the App

1. Open TermLinkky on your phone
2. Go to Devices → Pair New Device
3. Enter the Tailscale IP and port
4. Enter the 6-digit pairing code
5. Done! You're connected.

## Features

### 📱 Mobile App
- **Command Palette** - Quick access to common commands
- **Live Terminal** - Real-time output with ANSI colors
- **Custom Commands** - Add your own frequently-used commands
- **Categories** - AI Agents, Git, Node, Python, Docker, System

### 💻 Server
- **Tailscale-only binding** - Not exposed to the internet
- **Auto certificate generation** - No manual SSL setup
- **WebSocket terminal** - Real-time bidirectional I/O
- **Cross-platform** - Mac, Windows, Linux

## Security

| Layer | Protection |
|-------|------------|
| **Network** | Tailscale WireGuard encryption |
| **Binding** | Server only listens on Tailscale IP |
| **App Layer** | Certificate pinning after pairing |
| **Pairing** | 6-digit code prevents unauthorized setup |

**Why Tailscale?**
- No port forwarding or firewall config needed
- Works from anywhere (home, coffee shop, travel)
- Devices authenticated via Tailscale account
- Traffic never touches public internet

## Command Categories

| Category | Built-in Commands |
|----------|------------------|
| **AI Agents** | Claude Code, Codex, Aider |
| **Git** | status, pull, push, log, diff, stash |
| **Node.js** | npm install, run dev, build, test |
| **Python** | python3, pip install, pytest |
| **Docker** | ps, compose up, compose down |
| **System** | df, top, htop, ps |
| **Files** | ls, tree, find |
| **Terminal** | clear, exit, tmux |

## Project Structure

```
TermLinkky/
├── server/
│   ├── server.py         # Python WebSocket server
│   ├── requirements.txt
│   └── install.sh
├── TermLinkky/            # iOS app (Swift)
└── README.md

termlinkky_flutter/        # Cross-platform client (separate repo)
├── lib/
│   ├── models/
│   ├── services/
│   ├── screens/
│   └── widgets/
└── pubspec.yaml
```

## Platforms

**Server:** macOS, Windows, Linux  
**Client:** iOS, Android, macOS, Windows, Linux (via Flutter)

## License

MIT
