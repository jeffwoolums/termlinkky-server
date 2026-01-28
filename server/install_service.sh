#!/bin/bash
# Install TermLinkky as a systemd service

set -e

if [ "$EUID" -ne 0 ]; then
    echo "Please run with sudo"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
USER_NAME="${SUDO_USER:-$USER}"

cat > /etc/systemd/system/termlinkky.service << EOF
[Unit]
Description=TermLinkky Terminal Server
After=network.target tailscaled.service

[Service]
Type=simple
User=$USER_NAME
WorkingDirectory=$SCRIPT_DIR
ExecStart=/usr/bin/python3 $SCRIPT_DIR/server.py
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable termlinkky
systemctl start termlinkky

echo "TermLinkky service installed and started!"
echo
echo "Commands:"
echo "  sudo systemctl status termlinkky   # Check status"
echo "  sudo systemctl stop termlinkky     # Stop"
echo "  sudo systemctl restart termlinkky  # Restart"
echo "  sudo journalctl -u termlinkky -f   # View logs"
