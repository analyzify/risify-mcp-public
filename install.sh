#!/bin/sh
set -e

REPO="analyzify/risify-mcp-public"
BINARY="risify-mcp"
INSTALL_DIR="/usr/local/bin"

OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)

case "$ARCH" in
  x86_64|amd64) ARCH="amd64" ;;
  arm64|aarch64) ARCH="arm64" ;;
  *) echo "Unsupported architecture: $ARCH" && exit 1 ;;
esac

case "$OS" in
  linux|darwin) ;;
  *) echo "Unsupported OS: $OS" && exit 1 ;;
esac

TAG=$(curl -sL "https://api.github.com/repos/${REPO}/releases/latest" \
  | grep -o '"tag_name": *"[^"]*"' \
  | head -1 \
  | cut -d'"' -f4)

if [ -z "$TAG" ]; then
  echo "Error: No release found" && exit 1
fi

ASSET="${BINARY}_${OS}_${ARCH}.tar.gz"
URL="https://github.com/${REPO}/releases/download/${TAG}/${ASSET}"

echo "Downloading ${BINARY} ${TAG} for ${OS}/${ARCH}..."
tmpdir=$(mktemp -d)
curl -sL "$URL" | tar xz -C "$tmpdir"

echo "Installing to ${INSTALL_DIR}/${BINARY}..."
sudo mv "$tmpdir/$BINARY" "$INSTALL_DIR/$BINARY"
rm -rf "$tmpdir"

echo "Done! Run '${BINARY} version' to verify."
