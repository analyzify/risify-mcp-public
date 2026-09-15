#!/bin/sh
# Failure and success matrix for install.sh.
#
# Everything is served from a local fixture directory over loopback, so no
# release is downloaded and no installed artifact is ever executed — the
# "binary" in these archives is a text file, and the tests only ever inspect
# its contents.
#
# Usage: sh tests/install_test.sh

set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
installer="$root/install.sh"

BINARY="risify-mcp"
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)
case "$ARCH" in
  x86_64|amd64) ARCH="amd64" ;;
  arm64|aarch64) ARCH="arm64" ;;
esac
ASSET="${BINARY}_${OS}_${ARCH}.tar.gz"

work=$(mktemp -d)
server_pid=""
truncating_pid=""

cleanup() {
  [ -n "$server_pid" ] && kill "$server_pid" 2>/dev/null || true
  [ -n "$truncating_pid" ] && kill "$truncating_pid" 2>/dev/null || true
  rm -rf "$work"
}
trap cleanup EXIT INT TERM

pass=0
fail=0

sha256() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | cut -d' ' -f1
  else
    shasum -a 256 "$1" | cut -d' ' -f1
  fi
}

# release <tag> <binary-contents> [extra-file-in-archive]
release() {
  tag=$1
  contents=$2
  extra=${3:-}

  dir="$work/releases/$tag"
  mkdir -p "$dir" "$work/build"

  printf '%s\n' "$contents" > "$work/build/$BINARY"
  if [ -n "$extra" ]; then
    printf 'unexpected\n' > "$work/build/$extra"
    (cd "$work/build" && tar czf "$dir/$ASSET" "$BINARY" "$extra")
    rm -f "$work/build/$extra"
  else
    (cd "$work/build" && tar czf "$dir/$ASSET" "$BINARY")
  fi

  printf '%s  %s\n' "$(sha256 "$dir/$ASSET")" "$ASSET" > "$dir/checksums.txt"
}

# run <name> <expect-success 0|1> [env assignments...]
run() {
  name=$1
  want=$2
  shift 2

  target="$work/bin"
  rm -rf "$target"
  mkdir -p "$target"

  set +e
  out=$(env \
    RISIFY_MCP_INSTALL_DIR="$target" \
    RISIFY_MCP_BASE_URL="http://127.0.0.1:$port/releases" \
    RISIFY_MCP_API_URL="http://127.0.0.1:$port/latest.json" \
    "$@" \
    sh "$installer" 2>&1)
  got=$?
  set -e

  if [ "$want" -eq 0 ] && [ "$got" -ne 0 ]; then
    printf 'FAIL  %s\n      expected success, exit %s\n      %s\n' "$name" "$got" "$out"
    fail=$((fail + 1))
    return
  fi

  if [ "$want" -ne 0 ] && [ "$got" -eq 0 ]; then
    printf 'FAIL  %s\n      expected failure, installer reported success\n' "$name"
    fail=$((fail + 1))
    return
  fi

  # Nothing may reach the install directory on a failing run.
  if [ "$want" -ne 0 ] && [ -e "$target/$BINARY" ]; then
    printf 'FAIL  %s\n      a binary was installed despite the failure\n' "$name"
    fail=$((fail + 1))
    return
  fi

  # No staging leftovers, whichever way it went.
  if ls "$target"/.*.new >/dev/null 2>&1; then
    printf 'FAIL  %s\n      staging file left behind in the install directory\n' "$name"
    fail=$((fail + 1))
    return
  fi

  printf 'ok    %s\n' "$name"
  pass=$((pass + 1))
}

installed_is() {
  [ -f "$work/bin/$BINARY" ] && [ "$(cat "$work/bin/$BINARY")" = "$1" ]
}

# ---------------------------------------------------------------- fixtures --

mkdir -p "$work/releases"
release v1.0.0 "binary-v1.0.0"
release v2.0.0 "binary-v2.0.0"

# A release whose archive does not match its published checksum.
release v3.0.0 "binary-v3.0.0"
printf 'deadbeef%s  %s\n' "0000000000000000000000000000000000000000000000000000000" "$ASSET" \
  > "$work/releases/v3.0.0/checksums.txt"

# A release whose archive is not a valid gzip stream.
mkdir -p "$work/releases/v4.0.0"
printf 'this is not a tarball\n' > "$work/releases/v4.0.0/$ASSET"
printf '%s  %s\n' "$(sha256 "$work/releases/v4.0.0/$ASSET")" "$ASSET" \
  > "$work/releases/v4.0.0/checksums.txt"

# A release carrying a file beyond the binary: it must not be installed,
# but it must not block the install either.
release v5.0.0 "binary-v5.0.0" "payload.sh"

# The shape real releases actually have: documentation beside the binary.
release v8.0.0 "binary-v8.0.0" "README.md"

# A release with an archive but no checksums.txt at all.
mkdir -p "$work/releases/v6.0.0"
cp "$work/releases/v1.0.0/$ASSET" "$work/releases/v6.0.0/$ASSET"

# A release whose checksums.txt also lists a signature for the same asset.
# The signature line contains the asset name as a substring, so a match that is
# not anchored to the whole field picks its hash and fails a good download.
release v10.0.0 "binary-v10.0.0"
{
  printf 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff  %s.sig\n' "$ASSET"
  cat "$work/releases/v10.0.0/checksums.txt"
} > "$work/releases/v10.0.0/checksums.new"
mv "$work/releases/v10.0.0/checksums.new" "$work/releases/v10.0.0/checksums.txt"

# A release whose archive entry is a symlink rather than the binary. A listing
# shows only the name, so this is indistinguishable from the real thing until
# the entry type is checked.
mkdir -p "$work/releases/v11.0.0" "$work/linkbuild"
ln -sf "$work/secret.txt" "$work/linkbuild/$BINARY"
printf 'secret-contents\n' > "$work/secret.txt"
(cd "$work/linkbuild" && tar czf "$work/releases/v11.0.0/$ASSET" "$BINARY")
printf '%s  %s\n' "$(sha256 "$work/releases/v11.0.0/$ASSET")" "$ASSET" \
  > "$work/releases/v11.0.0/checksums.txt"

# A release whose checksums.txt lists other platforms but not this one.
mkdir -p "$work/releases/v7.0.0"
cp "$work/releases/v1.0.0/$ASSET" "$work/releases/v7.0.0/$ASSET"
printf 'aaaa  %s_someotheros_amd64.tar.gz\n' "$BINARY" > "$work/releases/v7.0.0/checksums.txt"

printf '{"tag_name": "v2.0.0"}\n' > "$work/latest.json"

# ------------------------------------------------------------------ server --

port=$(python3 "$root/tests/free_port.py")

(cd "$work" && python3 -m http.server "$port" --bind 127.0.0.1 >/dev/null 2>&1) &
server_pid=$!

i=0
while [ $i -lt 50 ]; do
  if curl -fsS "http://127.0.0.1:$port/latest.json" >/dev/null 2>&1; then
    break
  fi
  sleep 0.1
  i=$((i + 1))
done
[ $i -lt 50 ] || { echo "fixture server did not start"; exit 1; }

# A server that hangs up partway through the body, so the installer meets a
# download that stops mid-transfer rather than one that never starts.
truncating_port=$(python3 "$root/tests/free_port.py")
python3 "$root/tests/truncating_server.py" "$truncating_port" &
truncating_pid=$!

i=0
while [ $i -lt 50 ]; do
  if curl -s -o /dev/null --max-time 2 "http://127.0.0.1:$truncating_port/" 2>/dev/null; then
    break
  fi
  sleep 0.1
  i=$((i + 1))
done

# ------------------------------------------------------------------- cases --

run "valid install, pinned version"      0 RISIFY_MCP_VERSION=v1.0.0
installed_is "binary-v1.0.0" \
  || { echo "FAIL  installed binary is not the requested version"; fail=$((fail + 1)); }

run "valid install, latest resolved"     0
installed_is "binary-v2.0.0" \
  || { echo "FAIL  latest resolution installed the wrong version"; fail=$((fail + 1)); }

run "digest mismatch"                    1 RISIFY_MCP_VERSION=v3.0.0
run "corrupt archive"                    1 RISIFY_MCP_VERSION=v4.0.0
run "extra file beside the binary"       0 RISIFY_MCP_VERSION=v5.0.0
if [ -e "$work/bin/payload.sh" ]; then
  printf 'FAIL  an extra archive file reached the install directory\n'
  fail=$((fail + 1))
fi
run "documentation beside the binary"    0 RISIFY_MCP_VERSION=v8.0.0
run "checksums.txt missing"              1 RISIFY_MCP_VERSION=v6.0.0
run "asset absent from checksums.txt"    1 RISIFY_MCP_VERSION=v7.0.0
run "signature listed beside the asset"  0 RISIFY_MCP_VERSION=v10.0.0
run "archive entry is a symlink"         1 RISIFY_MCP_VERSION=v11.0.0
run "release tag does not exist"         1 RISIFY_MCP_VERSION=v9.9.9
run "download endpoint unreachable"      1 RISIFY_MCP_VERSION=v1.0.0 \
  RISIFY_MCP_BASE_URL="http://127.0.0.1:1/releases"
run "download interrupted mid-transfer"  1 RISIFY_MCP_VERSION=v1.0.0 \
  RISIFY_MCP_BASE_URL="http://127.0.0.1:$truncating_port/releases"

# The previous install must survive a later failed one.
rm -rf "$work/bin" && mkdir -p "$work/bin"
env RISIFY_MCP_VERSION=v1.0.0 RISIFY_MCP_INSTALL_DIR="$work/bin" \
  RISIFY_MCP_BASE_URL="http://127.0.0.1:$port/releases" \
  RISIFY_MCP_API_URL="http://127.0.0.1:$port/latest.json" \
  sh "$installer" >/dev/null 2>&1

set +e
env RISIFY_MCP_VERSION=v3.0.0 RISIFY_MCP_INSTALL_DIR="$work/bin" \
  RISIFY_MCP_BASE_URL="http://127.0.0.1:$port/releases" \
  RISIFY_MCP_API_URL="http://127.0.0.1:$port/latest.json" \
  sh "$installer" >/dev/null 2>&1
set -e

if installed_is "binary-v1.0.0"; then
  printf 'ok    failed upgrade leaves the previous binary in place\n'
  pass=$((pass + 1))
else
  printf 'FAIL  failed upgrade destroyed the previous binary\n'
  fail=$((fail + 1))
fi

# Temporary directories must not accumulate across runs.
before=$(find "${TMPDIR:-/tmp}" -maxdepth 1 -name 'tmp.*' 2>/dev/null | wc -l)
env RISIFY_MCP_VERSION=v4.0.0 RISIFY_MCP_INSTALL_DIR="$work/bin" \
  RISIFY_MCP_BASE_URL="http://127.0.0.1:$port/releases" \
  RISIFY_MCP_API_URL="http://127.0.0.1:$port/latest.json" \
  sh "$installer" >/dev/null 2>&1 || true
after=$(find "${TMPDIR:-/tmp}" -maxdepth 1 -name 'tmp.*' 2>/dev/null | wc -l)

if [ "$before" -eq "$after" ]; then
  printf 'ok    temporary directory cleaned up on failure\n'
  pass=$((pass + 1))
else
  printf 'FAIL  temporary directory leaked on failure\n'
  fail=$((fail + 1))
fi

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
