#!/usr/bin/env bash
set -euo pipefail

IPK="${1:?usage: import-m78-ipk.sh <78.ipk> [--with-geodata]}"
WITH_GEODATA="${2:-}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PKG_DIR="$ROOT_DIR/packages/m78-x86"
FILES_DIR="$PKG_DIR/files"

[[ -f "$IPK" ]] || { echo "ERROR: file not found: $IPK" >&2; exit 2; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/outer" "$WORK/control" "$WORK/data"

# This M78 package is a gzip-compressed tar containing control.tar.gz/data.tar.gz,
# not the more common ar-wrapped IPK variant.
if tar -tzf "$IPK" >/dev/null 2>&1; then
  tar -xzf "$IPK" -C "$WORK/outer"
elif ar t "$IPK" >/dev/null 2>&1; then
  (cd "$WORK/outer" && ar x "$IPK")
else
  echo "ERROR: unsupported IPK container: $IPK" >&2
  exit 3
fi

DATA_ARCHIVE=""
for f in data.tar.zst data.tar.xz data.tar.gz data.tar.bz2 data.tar; do
  if [[ -f "$WORK/outer/$f" ]]; then DATA_ARCHIVE="$WORK/outer/$f"; break; fi
done
[[ -n "$DATA_ARCHIVE" ]] || { echo "ERROR: data archive not found" >&2; exit 4; }

tar -xf "$DATA_ARCHIVE" -C "$WORK/data"

BIN="$WORK/data/usr/bin/netflow_x86_64"
[[ -x "$BIN" ]] || { echo "ERROR: x86_64 binary not found in package" >&2; exit 5; }

rm -rf "$FILES_DIR"
mkdir -p "$FILES_DIR"

copy_path() {
  local rel="$1"
  if [[ -e "$WORK/data/$rel" ]]; then
    mkdir -p "$FILES_DIR/$(dirname "$rel")"
    cp -a "$WORK/data/$rel" "$FILES_DIR/$rel"
  fi
}

copy_path etc/config/netflow
copy_path etc/init.d/netflow
copy_path etc/uci-defaults/luci-app-netflow
copy_path usr/lib/lua/luci/controller/netflow.lua
copy_path usr/lib/lua/luci/view/netflow/main.htm
copy_path usr/bin/netflow_x86_64

if [[ "$WITH_GEODATA" == "--with-geodata" ]]; then
  mkdir -p "$FILES_DIR/etc/netflow/mihomo"
  for f in GeoLite2-ASN.mmdb geoip.dat geoip.metadb geosite.dat; do
    [[ -f "$WORK/data/etc/netflow/mihomo/$f" ]] &&       cp -a "$WORK/data/etc/netflow/mihomo/$f" "$FILES_DIR/etc/netflow/mihomo/$f"
  done
fi

chmod 0755 "$FILES_DIR/usr/bin/netflow_x86_64"
chmod 0755 "$FILES_DIR/etc/init.d/netflow" "$FILES_DIR/etc/uci-defaults/luci-app-netflow"

echo "Imported M78 x86_64 package files into:"
echo "  $FILES_DIR"
echo
du -sh "$FILES_DIR"
echo
echo "Other architecture binaries were not imported."
if [[ "$WITH_GEODATA" != "--with-geodata" ]]; then
  echo "Bundled GeoIP/GeoSite databases were omitted (use --with-geodata to keep them)."
fi
