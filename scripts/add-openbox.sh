#!/usr/bin/env bash
set -euo pipefail

OPENWRT_DIR="${1:?usage: add-openbox.sh <openwrt-dir>}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "$ROOT_DIR/versions.env"

FILES_DIR="$OPENWRT_DIR/files"
CACHE_DIR="$HOME/openwrt-build/source-cache/open-box"
ASSET="open-box-${OPENBOX_VERSION}-linux-x64.tar.gz"
CACHE_FILE="$CACHE_DIR/$ASSET"
URL="https://github.com/liandu2024/Open-Box/releases/download/${OPENBOX_VERSION}/$ASSET"

mkdir -p "$CACHE_DIR" "$FILES_DIR"

verify_asset() {
  [[ -f "$CACHE_FILE" ]] || return 1
  printf '%s  %s\n' "$OPENBOX_SHA256" "$CACHE_FILE" | sha256sum -c - >/dev/null 2>&1
}

if ! verify_asset; then
  rm -f "$CACHE_FILE"
  echo "==> Downloading Open-Box $OPENBOX_VERSION"
  if ! curl -fL --retry 3 --connect-timeout 15 -o "$CACHE_FILE" "$URL"; then
    echo "Direct GitHub download failed, retrying through ghfast.top..." >&2
    curl -fL --retry 3 --connect-timeout 15       -o "$CACHE_FILE" "https://ghfast.top/$URL"
  fi
fi

if ! verify_asset; then
  echo "ERROR: Open-Box SHA256 verification failed: $CACHE_FILE" >&2
  exit 12
fi

TARGET="$FILES_DIR/opt/open-box"
rm -rf "$TARGET"
mkdir -p "$TARGET"
tar -xzf "$CACHE_FILE" -C "$TARGET"

for required in   meta.json   openwrt/initd/openbox   openwrt/initd/openbox-panel   openwrt/bin/open-box   openwrt/luci/root/usr/share/luci/menu.d/luci-app-openbox.json   openwrt/luci/root/usr/share/rpcd/acl.d/luci-app-openbox.json; do
  if [[ ! -e "$TARGET/$required" ]]; then
    echo "ERROR: Open-Box release layout changed; missing: $required" >&2
    exit 13
  fi
done

mkdir -p   "$FILES_DIR/etc/init.d"   "$FILES_DIR/etc/uci-defaults"   "$FILES_DIR/usr/bin"   "$FILES_DIR/usr/share/luci/menu.d"   "$FILES_DIR/usr/share/rpcd/acl.d"   "$FILES_DIR/www/luci-static/resources/view/openbox"   "$TARGET/data"

cp "$TARGET/openwrt/initd/openbox" "$FILES_DIR/etc/init.d/openbox"
cp "$TARGET/openwrt/initd/openbox-panel" "$FILES_DIR/etc/init.d/openbox-panel"
chmod +x "$FILES_DIR/etc/init.d/openbox" "$FILES_DIR/etc/init.d/openbox-panel"

cp "$TARGET/openwrt/luci/htdocs/luci-static/resources/view/openbox/"*.js   "$FILES_DIR/www/luci-static/resources/view/openbox/"
cp "$TARGET/openwrt/luci/root/usr/share/luci/menu.d/luci-app-openbox.json"   "$FILES_DIR/usr/share/luci/menu.d/luci-app-openbox.json"
cp "$TARGET/openwrt/luci/root/usr/share/rpcd/acl.d/luci-app-openbox.json"   "$FILES_DIR/usr/share/rpcd/acl.d/luci-app-openbox.json"

ln -sfn /opt/open-box/openwrt/bin/open-box "$FILES_DIR/usr/bin/open-box"

# 与官方安装器默认值保持一致：首次只启动面板，不启动代理内核。
printf 'direct\n' > "$TARGET/data/channel"
printf '3036\n' > "$TARGET/data/panel-port"

cat > "$FILES_DIR/etc/uci-defaults/99-openbox" <<'EOF'
#!/bin/sh
/etc/init.d/openbox-panel enable >/dev/null 2>&1 || true
rm -rf /tmp/luci-*cache* 2>/dev/null || true
/etc/init.d/openbox-panel start >/dev/null 2>&1 || true
exit 0
EOF
chmod +x "$FILES_DIR/etc/uci-defaults/99-openbox"

echo "Open-Box $OPENBOX_VERSION staged into rootfs."
echo "  payload: /opt/open-box"
echo "  panel:   http://<LAN-IP>:3036"
