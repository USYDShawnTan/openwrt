#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "$ROOT_DIR/versions.env"

TARGET="$ROOT_DIR/packages/m78-x86/files/www/zashboard"
CACHE_DIR="${HOME}/openwrt-build/source-cache/zashboard"
ASSET="dist-no-fonts.zip"
CACHE_FILE="$CACHE_DIR/zashboard-${ZASHBOARD_VERSION}-$ASSET"
URL="https://github.com/Zephyruso/zashboard/releases/download/${ZASHBOARD_VERSION}/$ASSET"

mkdir -p "$CACHE_DIR"

verify() {
  [[ -f "$CACHE_FILE" ]] || return 1
  printf '%s  %s\n' "$ZASHBOARD_SHA256" "$CACHE_FILE" | sha256sum -c - >/dev/null 2>&1
}

if ! verify; then
  rm -f "$CACHE_FILE"
  echo "==> Downloading Zashboard $ZASHBOARD_VERSION"
  curl -fL --retry 3 --connect-timeout 15 -o "$CACHE_FILE" "$URL"
fi

if ! verify; then
  echo "ERROR: Zashboard SHA256 verification failed: $CACHE_FILE" >&2
  exit 21
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
unzip -q "$CACHE_FILE" -d "$TMP_DIR"

INDEX_FILE="$(find "$TMP_DIR" -type f -name index.html -print -quit)"
if [[ -z "$INDEX_FILE" ]]; then
  echo "ERROR: Zashboard archive layout changed: index.html missing" >&2
  find "$TMP_DIR" -maxdepth 3 -type f | head -n 50 >&2 || true
  exit 22
fi

WEB_ROOT="$(dirname "$INDEX_FILE")"
rm -rf "$TARGET"
mkdir -p "$TARGET"
cp -a "$WEB_ROOT/." "$TARGET/"

test -f "$TARGET/index.html"
echo "Zashboard $ZASHBOARD_VERSION vendored into packages/m78-x86/files/www/zashboard (source: ${WEB_ROOT#"$TMP_DIR"/})"
