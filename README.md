# TermLinky

Remote terminal access for developers. Connect your iPhone/iPad to your Mac for on-the-go terminal monitoring and command execution.

## Features

### 📱 iOS App
- **Secure Pairing** - Certificate pinning ensures you're connecting to YOUR Mac
- **Command Palette** - Quick access to common commands (git, npm, docker, AI agents)
- **Live Terminal** - Real-time output with ANSI color support
- **Custom Commands** - Add your own frequently-used commands
- **Category Filtering** - Organize and filter commands by type

### 💻 Mac Server
- **Self-signed HTTPS** - Automatic certificate generation
- **WebSocket Terminal** - Real-time bidirectional communication
- **tmux Integration** - Attach to existing sessions
- **Bonjour Discovery** - Automatic local network discovery

## Architecture

```
┌─────────────┐         TLS + Cert Pinning        ┌─────────────┐
│   iOS App   │ ◄──────────────────────────────► │  Mac Server │
│             │         WebSocket                 │             │
│  - Pairing  │                                   │  - HTTPS    │
│  - Terminal │                                   │  - PTY      │
│  - Commands │                                   │  - tmux     │
└─────────────┘                                   └─────────────┘
```

### Pairing Flow

1. Mac server generates self-signed certificate on first run
2. Server displays 6-digit pairing code (derived from cert fingerprint)
3. User enters code in iOS app
4. iOS app stores certificate fingerprint
5. All future connections verify cert matches (certificate pinning)

This ensures:
- No MITM attacks possible after pairing
- No external CA or Let's Encrypt needed
- Works over any network (local, Tailscale, etc.)

## Installation

### iOS App

Build with Xcode 15+ or use XcodeGen:

```bash
# Install xcodegen
brew install xcodegen

# Generate project
cd TermLinky
xcodegen generate

# Open in Xcode
open TermLinky.xcodeproj
```

### Mac Server

```bash
cd server
./install.sh
```

Or manually:

```bash
# Install dependencies
pip3 install -r requirements.txt

# Generate certificate
./generate-cert.sh

# Run server
python3 server.py
```

## Quick Commands

Built-in commands organized by category:

| Category | Commands |
|----------|----------|
| **AI Agents** | Claude Code, Codex, Aider |
| **Git** | status, pull, push, log, diff, stash |
| **Node.js** | npm install, run dev, build, test |
| **Python** | python3, pip install, pytest |
| **Docker** | ps, compose up, compose down |
| **System** | df, top, htop, ps |
| **Files** | ls, tree, find |
| **Terminal** | clear, exit, tmux |

Add custom commands in Settings → Quick Commands.

## Security

- **Certificate Pinning**: After pairing, only YOUR Mac's certificate is trusted
- **Self-signed Certs**: No external CA dependencies
- **Local-first**: No cloud services required
- **Code Verification**: Pairing code prevents unauthorized access

## Requirements

- iOS 17.0+
- macOS 14.0+ (for server)
- Python 3.9+ (for server)

## License

MIT
