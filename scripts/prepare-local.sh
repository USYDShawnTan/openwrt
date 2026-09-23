#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "$ROOT_DIR/versions.env"
OPENWRT_DIR="${1:-$HOME/openwrt-build/openwrt}"

if [[ "$(id -u)" -eq 0 ]]; then
  echo "ERROR: Do not build OpenWrt as root." >&2
  echo "Run as your normal build user (for example: xiaotan)." >&2
  exit 3
fi

if [[ ! -d "$OPENWRT_DIR" || ! -f "$OPENWRT_DIR/Makefile" || ! -d "$OPENWRT_DIR/scripts" ]]; then
  echo "OpenWrt source tree not found: $OPENWRT_DIR" >&2
  exit 2
fi

# 权限预检：避免编到一半才因为 root:root 文件失败。
for dir in "$ROOT_DIR" "$OPENWRT_DIR"; do
  if [[ ! -w "$dir" ]]; then
    echo "ERROR: directory is not writable by $(id -un):" >&2
    echo "  $dir" >&2
    echo >&2
    echo "Fix ownership once, for example:" >&2
    echo "  sudo chown -R $(id -un):$(id -gn) '$dir'" >&2
    exit 6
  fi
done

mkdir -p "$HOME/openwrt-build/source-cache"
if [[ ! -w "$HOME/openwrt-build/source-cache" ]]; then
  echo "ERROR: source cache is not writable:" >&2
  echo "  $HOME/openwrt-build/source-cache" >&2
  echo "Fix: sudo chown -R $(id -un):$(id -gn) '$HOME/openwrt-build'" >&2
  exit 7
fi

# 用 Release Tag 校验，不要求日常维护 OpenWrt SHA。
expected="$(git -C "$OPENWRT_DIR" rev-parse "${OPENWRT_VERSION}^{commit}" 2>/dev/null || true)"
current="$(git -C "$OPENWRT_DIR" rev-parse HEAD 2>/dev/null || true)"
if [[ -z "$expected" ]]; then
  echo "ERROR: OpenWrt tag not found locally: $OPENWRT_VERSION" >&2
  echo "Run: git -C '$OPENWRT_DIR' fetch --tags" >&2
  exit 4
fi
if [[ "$current" != "$expected" ]]; then
  echo "ERROR: OpenWrt source is not checked out at $OPENWRT_VERSION." >&2
  echo "Run: git -C '$OPENWRT_DIR' checkout $OPENWRT_VERSION" >&2
  exit 5
fi

echo "==> Xiaotan build: $BUILD_VERSION"
echo "==> OpenWrt: $OPENWRT_VERSION"

echo "==> source cache: $HOME/openwrt-build/source-cache"

bash "$ROOT_DIR/scripts/reset-network-patches.sh" "$OPENWRT_DIR"
bash "$ROOT_DIR/scripts/prepare-feeds.sh" "$OPENWRT_DIR"
bash "$ROOT_DIR/scripts/add-packages.sh" "$OPENWRT_DIR"
bash "$ROOT_DIR/scripts/add-sonic-fullcone.sh" "$OPENWRT_DIR"

cd "$OPENWRT_DIR"
cp "$ROOT_DIR/config/xiaotan.config" .config
rm -rf files
mkdir -p files
cp -a "$ROOT_DIR/files/." files/
bash "$ROOT_DIR/scripts/select-packages.sh" "$OPENWRT_DIR"

echo
echo "Local tree prepared successfully."
