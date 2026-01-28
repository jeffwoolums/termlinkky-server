#!/bin/bash
# TermLinkky Server Installer for Linux

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo "TermLinkky Server Installer for Linux"
echo "======================================"
echo

# Check Python
if ! command -v python3 &> /dev/null; then
    echo "Error: Python 3 is required"
    echo "Install with: sudo apt install python3 python3-pip"
    exit 1
fi

# Install dependencies
echo "Installing Python dependencies..."
pip3 install --user aiohttp

# Generate certificate
if [ ! -f "certs/server.crt" ]; then
    echo "Generating SSL certificate..."
    mkdir -p certs
    openssl req -x509 -newkey rsa:4096 \
        -keyout certs/server.key \
        -out certs/server.crt \
        -days 3650 \
        -nodes \
        -subj "/CN=$(hostname)/O=TermLinkky" \
        2>/dev/null
fi

echo
echo "Installation complete!"
echo
echo "To start manually:"
echo "  python3 $SCRIPT_DIR/server.py"
echo
echo "To install as systemd service:"
echo "  sudo $SCRIPT_DIR/install_service.sh"
