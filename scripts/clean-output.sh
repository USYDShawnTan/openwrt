#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
rm -rf "$ROOT_DIR/dist"
echo "Removed local dist/ only. OpenWrt build/download/ccache caches were kept."
