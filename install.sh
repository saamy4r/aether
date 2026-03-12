#!/bin/bash
set -e

REPO="saamy4r/aether"
INSTALL_DIR="/opt/aether"
BIN_LINK="/usr/local/bin/aether"

echo "Installing Aether..."

LATEST=$(curl -s "https://api.github.com/repos/$REPO/releases/latest" | grep '"tag_name"' | cut -d'"' -f4)
URL="https://github.com/$REPO/releases/download/$LATEST/aether-linux-$LATEST.tar.gz"

TMP=$(mktemp -d)
curl -L "$URL" -o "$TMP/aether.tar.gz"
sudo mkdir -p "$INSTALL_DIR"
sudo tar -xzf "$TMP/aether.tar.gz" -C "$INSTALL_DIR"
sudo ln -sf "$INSTALL_DIR/aether" "$BIN_LINK"
rm -rf "$TMP"

echo "Done. Run: aether"
