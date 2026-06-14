#!/usr/bin/env bash
# Quick setup script for macOS-XFCE (Dual-DE)
set -e

DEST="$HOME/.macos-xfce"
REPO="https://github.com/vannizanotto/macos-xfce.git"

echo "🍏 Preparing macOS-XFCE installation..."

if ! command -v git >/dev/null 2>&1; then
    echo "Installing git..."
    sudo apt-get update && sudo apt-get install -y git
fi

if [ ! -d "$DEST" ]; then
    echo "Cloning repository to $DEST..."
    git clone "$REPO" "$DEST"
else
    echo "Updating existing repository..."
    cd "$DEST" && git pull
fi

cd "$DEST"
echo "Starting installer..."
exec ./install.sh "$@"
