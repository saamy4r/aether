#!/bin/bash
set -e

REPO="saamy4r/aether"
INSTALL_DIR="/opt/aether"
BIN_LINK="/usr/local/bin/aether"

echo "Installing Aether..."

# Get latest release tag
LATEST=$(curl -sf "https://api.github.com/repos/$REPO/releases/latest" \
  | grep '"tag_name"' | cut -d'"' -f4)

if [ -z "$LATEST" ]; then
  echo ""
  echo "Error: No release found at https://github.com/$REPO/releases"
  echo "Make sure the release has been published on GitHub."
  exit 1
fi

echo "Found release: $LATEST"
URL="https://github.com/$REPO/releases/download/$LATEST/aether-linux.tar.gz"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

echo "Downloading $URL ..."
HTTP_CODE=$(curl -L "$URL" -o "$TMP/aether.tar.gz" -w "%{http_code}" --silent --show-error)

if [ "$HTTP_CODE" != "200" ]; then
  echo ""
  echo "Error: Download failed (HTTP $HTTP_CODE)"
  echo "Check that the release asset exists at: $URL"
  exit 1
fi

# Validate it's actually a gzip file
if ! file "$TMP/aether.tar.gz" | grep -q "gzip"; then
  echo ""
  echo "Error: Downloaded file is not a valid archive."
  echo "The release asset may not have been uploaded yet."
  exit 1
fi

echo "Installing to $INSTALL_DIR ..."
sudo mkdir -p "$INSTALL_DIR"
sudo tar -xzf "$TMP/aether.tar.gz" --strip-components=1 -C "$INSTALL_DIR"
sudo ln -sf "$INSTALL_DIR/aether" "$BIN_LINK"

# Install icon
ICON_SRC="$INSTALL_DIR/data/flutter_assets/assets/icon/icon.png"
ICON_DEST="/usr/share/icons/hicolor/256x256/apps/aether.png"
if [ -f "$ICON_SRC" ]; then
  sudo mkdir -p "$(dirname "$ICON_DEST")"
  sudo cp "$ICON_SRC" "$ICON_DEST"
fi

# Install .desktop file
sudo tee /usr/share/applications/aether.desktop > /dev/null <<'DESKTOP'
[Desktop Entry]
Name=Aether
Comment=VPS Desktop Environment over SSH
Exec=/usr/local/bin/aether
Icon=aether
Type=Application
Categories=Network;RemoteAccess;
StartupNotify=true
DESKTOP

# Refresh icon cache and desktop database
if command -v gtk-update-icon-cache &>/dev/null; then
  sudo gtk-update-icon-cache -f -t /usr/share/icons/hicolor 2>/dev/null || true
fi
if command -v update-desktop-database &>/dev/null; then
  sudo update-desktop-database /usr/share/applications 2>/dev/null || true
fi

echo ""
echo "Aether installed successfully!"
echo "Run it with: aether"
echo "Or find it in your application menu."
