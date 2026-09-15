#!/bin/sh
set -eu

# Installs the risify-mcp binary from a published GitHub release, verifying it
# against the release's checksums.txt before installing.
#
# Overrides, all optional:
#   RISIFY_MCP_VERSION       install this tag instead of the latest release
#   RISIFY_MCP_INSTALL_DIR   install somewhere other than /usr/local/bin
#   RISIFY_MCP_BASE_URL      release download base, for testing
#   RISIFY_MCP_API_URL       latest-release API endpoint, for testing

REPO="analyzify/risify-mcp-public"
BINARY="risify-mcp"
INSTALL_DIR="${RISIFY_MCP_INSTALL_DIR:-/usr/local/bin}"
VERSION="${RISIFY_MCP_VERSION:-}"
BASE_URL="${RISIFY_MCP_BASE_URL:-https://github.com/${REPO}/releases/download}"
API_URL="${RISIFY_MCP_API_URL:-https://api.github.com/repos/${REPO}/releases/latest}"

tmpdir=""

cleanup() {
  if [ -n "$tmpdir" ] && [ -d "$tmpdir" ]; then
    rm -rf "$tmpdir"
  fi
}

trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

fail() {
  echo "Error: $*" >&2
  exit 1
}

need() {
  command -v "$1" >/dev/null 2>&1 || fail "$1 is required but not installed"
}

need curl
need tar

# -f so an HTTP error is an error; without it curl writes the error page and
# exits 0.
fetch() {
  curl -fsSL --retry 2 --retry-delay 1 -o "$2" "$1" \
    || fail "download failed: $1"
}

OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)

case "$ARCH" in
  x86_64|amd64) ARCH="amd64" ;;
  arm64|aarch64) ARCH="arm64" ;;
  *) fail "unsupported architecture: $ARCH" ;;
esac

case "$OS" in
  linux|darwin) ;;
  *) fail "unsupported OS: $OS" ;;
esac

tmpdir=$(mktemp -d)

if [ -z "$VERSION" ]; then
  echo "Looking up the latest release..."
  fetch "$API_URL" "$tmpdir/release.json"

  VERSION=$(grep -o '"tag_name"[ ]*:[ ]*"[^"]*"' "$tmpdir/release.json" \
    | head -1 | cut -d'"' -f4)

  [ -n "$VERSION" ] || fail "no release found at $API_URL"
fi

ASSET="${BINARY}_${OS}_${ARCH}.tar.gz"
archive="$tmpdir/$ASSET"
checksums="$tmpdir/checksums.txt"

echo "Downloading ${BINARY} ${VERSION} for ${OS}/${ARCH}..."
fetch "${BASE_URL}/${VERSION}/${ASSET}" "$archive"
fetch "${BASE_URL}/${VERSION}/checksums.txt" "$checksums"

# Whole field, not a substring: a "<asset>.sig" line contains the asset name
# and would supply the wrong hash. Leading "*" is sha256sum's binary marker.
expected=$(awk -v asset="$ASSET" '
  { name = $2; sub(/^\*/, "", name) }
  name == asset { print $1; exit }
' "$checksums")
[ -n "$expected" ] || fail "$ASSET is not listed in checksums.txt for $VERSION"

if command -v sha256sum >/dev/null 2>&1; then
  actual=$(sha256sum "$archive" | cut -d' ' -f1)
elif command -v shasum >/dev/null 2>&1; then
  actual=$(shasum -a 256 "$archive" | cut -d' ' -f1)
else
  fail "sha256sum or shasum is required to verify the download"
fi

if [ "$expected" != "$actual" ]; then
  fail "checksum mismatch for $ASSET
  expected $expected
  actual   $actual
The download was corrupted or tampered with; nothing has been installed."
fi

echo "Checksum verified."

# Inspected before extraction: an absolute or traversing path would be written
# wherever it points. Extra files are not rejected — only the binary is
# installed, and pinning the archive's exact shape would couple this script to
# release packaging it cannot see.
tar tzf "$archive" > "$tmpdir/contents.txt" 2>/dev/null \
  || fail "$ASSET is not a readable tar.gz archive"

while IFS= read -r entry; do
  case "$entry" in
    "") continue ;;
    /*) fail "archive contains an absolute path: $entry" ;;
    ../*|*/../*|*/..) fail "archive contains a traversing path: $entry" ;;
  esac
done < "$tmpdir/contents.txt"

grep -qxF "$BINARY" "$tmpdir/contents.txt" \
  || fail "archive does not contain the expected $BINARY binary"

extract="$tmpdir/extract"
mkdir -p "$extract"
tar xzf "$archive" -C "$extract" || fail "failed to extract $ASSET"

# The listing above shows names, not types, so a symlink named risify-mcp is
# indistinguishable there — and both -f and cp would follow it.
if [ -n "$(find "$extract" -type l 2>/dev/null | head -1)" ]; then
  fail "archive contains a symbolic link, which a release archive should not"
fi

staged="$extract/$BINARY"
[ -f "$staged" ] || fail "$BINARY is missing after extraction"
chmod 0755 "$staged"

SUDO=""
if [ ! -w "$INSTALL_DIR" ]; then
  if command -v sudo >/dev/null 2>&1; then
    SUDO="sudo"
  else
    fail "$INSTALL_DIR is not writable and sudo is not available"
  fi
fi

if [ ! -d "$INSTALL_DIR" ]; then
  $SUDO mkdir -p "$INSTALL_DIR" || fail "cannot create $INSTALL_DIR"
fi

echo "Installing to ${INSTALL_DIR}/${BINARY}..."

# Staged beside the target so the last step is a same-filesystem rename: either
# the new binary is in place or the previous one still is, never neither.
$SUDO cp "$staged" "$INSTALL_DIR/.$BINARY.new" \
  || fail "cannot stage the new binary in $INSTALL_DIR"
$SUDO chmod 0755 "$INSTALL_DIR/.$BINARY.new"

if ! $SUDO mv -f "$INSTALL_DIR/.$BINARY.new" "$INSTALL_DIR/$BINARY"; then
  $SUDO rm -f "$INSTALL_DIR/.$BINARY.new"
  fail "cannot install to $INSTALL_DIR/$BINARY"
fi

echo "Done! Installed ${BINARY} ${VERSION}."
echo "Run '${BINARY} version' to verify."
