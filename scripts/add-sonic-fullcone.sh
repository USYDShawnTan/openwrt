#!/usr/bin/env bash
set -euo pipefail

OPENWRT_DIR="${1:?usage: add-sonic-fullcone.sh <openwrt-dir>}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "$ROOT_DIR/versions.env"
# shellcheck disable=SC1091
source "$ROOT_DIR/scripts/source-locks.sh"
# shellcheck disable=SC1091
source "$ROOT_DIR/scripts/lib-source-cache.sh"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
SOURCE_DIR="$TMP/source"
INSTALLER="$TMP/add_sonic_fullcone.sh"

export_source_tree mufeng05/openwrt-sonic-fullcone \
  openwrt-sonic-fullcone "$SONIC_FULLCONE_SOURCE_REF" "$SOURCE_DIR"

cp "$SOURCE_DIR/add_sonic_fullcone.sh" "$INSTALLER"
chmod +x "$INSTALLER"

# 上游 installer 默认再次 clone master。改成复用已经下载并锁定的 tarball 源码，
# 因此不会产生第二次网络访问，也不会跟随 master 漂移。
python3 - "$INSTALLER" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
s = p.read_text()
old = 'if ! git clone --depth=1 --single-branch "$REPO" "$TMPDIR/sonic-fullcone" 2>&1; then'
new = 'if ! cp -a "$XIAOTAN_SONIC_SOURCE" "$TMPDIR/sonic-fullcone" 2>&1; then'
if old not in s:
    raise SystemExit('ERROR: upstream sonic-fullcone installer layout changed')
p.write_text(s.replace(old, new, 1))
PY

export XIAOTAN_SONIC_SOURCE="$SOURCE_DIR"
cd "$OPENWRT_DIR"
bash "$INSTALLER"

# 使用与当前 LuCI 匹配的补丁。Build/Prepare 会将它应用到构建目录。
# 不直接改 feeds 源码，避免二次打补丁。
install -m 0644 "$ROOT_DIR/patches/luci-app-firewall-fullcone.patch" \
  "$OPENWRT_DIR/feeds/luci/applications/luci-app-firewall/patches/001-add-fullcone-options.patch"

# APK 按版本号选包，旧 feeds 的高版本残留可能覆盖本次补丁构建。
# 归档而不是删除；随后正常 make 会重建本包。
if [[ -d "$OPENWRT_DIR/bin/packages" ]]; then
  BACKUP_DIR="$(mktemp -d "$ROOT_DIR/.backup-firewall-apks.XXXXXX")"
  find "$OPENWRT_DIR/bin/packages" -type f -name 'luci-app-firewall-*.apk' \
    -exec mv -t "$BACKUP_DIR" -- {} +
fi

echo "SONiC FullCone applied: $SONIC_FULLCONE_VERSION"
