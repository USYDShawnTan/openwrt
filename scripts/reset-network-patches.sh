#!/usr/bin/env bash
set -euo pipefail
OPENWRT_DIR="${1:?usage: reset-network-patches.sh <openwrt-dir>}"
cd "$OPENWRT_DIR"

# v4.5 从干净的 OpenWrt Release 网络源码重新应用 SONiC FullCone。
# 只恢复 TurboACC / FullCone 会碰到的源码区域；不会删除 dl/.ccache/build_dir/staging_dir。
paths=(
  target/linux/generic
  package/libs/libnftnl
  package/network/config/firewall
  package/network/config/firewall4
  package/network/utils/iptables
  package/network/utils/nftables
)

echo "==> resetting network patch areas to OpenWrt release baseline"
git restore -- "${paths[@]}"
git clean -fd -- "${paths[@]}"
rm -rf package/turboacc package/xiaotan
