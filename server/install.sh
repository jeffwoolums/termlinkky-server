#!/bin/bash
# TermLinky Server Installer

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo "Installing TermLinky Server..."

# Check Python
if ! command -v python3 &> /dev/null; then
    echo "Error: Python 3 is required"
    exit 1
fi

# Install dependencies
echo "Installing Python dependencies..."
python3 -m pip install -r requirements.txt --quiet

# Generate certificate if needed
if [ ! -f "certs/server.crt" ]; then
    echo "Generating SSL certificate..."
    mkdir -p certs
    openssl req -x509 -newkey rsa:4096 \
        -keyout certs/server.key \
        -out certs/server.crt \
        -days 3650 \
        -nodes \
        -subj "/CN=$(hostname)/O=TermLinky" \
        2>/dev/null
fi

echo ""
echo "✓ Installation complete!"
echo ""
echo "To start the server:"
echo "  python3 $SCRIPT_DIR/server.py"
echo ""
echo "Or run in background:"
echo "  nohup python3 $SCRIPT_DIR/server.py > /tmp/termlinky.log 2>&1 &"
