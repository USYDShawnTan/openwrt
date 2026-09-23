#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "$ROOT_DIR/versions.env"
OPENWRT_DIR="${1:-$HOME/openwrt-build/openwrt}"
JOBS="${JOBS:-$(nproc)}"
DIST_DIR="$ROOT_DIR/dist"

bash "$ROOT_DIR/scripts/prepare-local.sh" "$OPENWRT_DIR"

cd "$OPENWRT_DIR"

echo
echo "==> Downloading sources with $JOBS jobs"
make download -j"$JOBS"

echo
echo "==> Building firmware with $JOBS jobs"
if ! make -j"$JOBS"; then
  echo >&2
  echo "Build failed. Re-run the following command for the detailed error:" >&2
  echo "  cd '$OPENWRT_DIR' && make -j1 V=s" >&2
  exit 1
fi

FIRMWARE="$(find bin/targets/x86/64 -maxdepth 1 -type f -name 'openwrt-x86-64-generic-squashfs-combined-efi.img.gz' -print -quit)"
if [[ -z "$FIRMWARE" ]]; then
  echo "ERROR: expected combined EFI firmware was not produced." >&2
  exit 4
fi

rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"
cp "$FIRMWARE" "$DIST_DIR/"

echo
echo "========================================"
echo " Xiaotan OpenWrt $BUILD_VERSION build completed"
echo "========================================"
ls -lh "$DIST_DIR/$(basename "$FIRMWARE")"
echo
echo "Output directory: $DIST_DIR"
echo
echo "Local caches retained in OpenWrt tree:"
echo "  $OPENWRT_DIR/dl"
echo "  $OPENWRT_DIR/.ccache"
echo "  $OPENWRT_DIR/build_dir"
echo "  $OPENWRT_DIR/staging_dir"
