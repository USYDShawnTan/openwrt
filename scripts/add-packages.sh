#!/usr/bin/env bash
set -euo pipefail

OPENWRT_DIR="${1:?usage: add-packages.sh <openwrt-dir>}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "$ROOT_DIR/versions.env"
# shellcheck disable=SC1091
source "$ROOT_DIR/scripts/source-locks.sh"
# shellcheck disable=SC1091
source "$ROOT_DIR/scripts/lib-source-cache.sh"

PKG_DIR="$OPENWRT_DIR/package/xiaotan"
rm -rf "$PKG_DIR"
mkdir -p "$PKG_DIR"

# ---------- 正式 Release / Tag：codeload tarball + 本地缓存 ----------
export_source_tree jerrykuku/luci-theme-argon \
  luci-theme-argon "$ARGON_VERSION" "$PKG_DIR/luci-theme-argon"

export_source_tree jerrykuku/luci-app-argon-config \
  luci-app-argon-config "$ARGON_CONFIG_VERSION" "$PKG_DIR/luci-app-argon-config"

# apk 系统没有 luci.model.ipkg，直接查询背景目录所在文件系统的容量。
patch --batch --fuzz=0 -d "$PKG_DIR/luci-app-argon-config" -p1 \
  < "$ROOT_DIR/patches/luci-app-argon-config-apk.patch"

# 清除旧翻译 APK，避免 apk 优先选取历史版本。当前翻译随插件重新生成。
if [[ -d "$OPENWRT_DIR/bin/packages" ]]; then
  find "$OPENWRT_DIR/bin/packages" -type f \
    -name 'luci-i18n-argon-config-zh-cn-*.apk' -delete
fi

# EasyTier 保持完整仓库布局，内部 Makefile 共用 version.mk。
export_source_tree EasyTier/luci-app-easytier \
  luci-app-easytier "$EASYTIER_VERSION" "$PKG_DIR/easytier-suite"

export_source_tree sirpdboy/luci-app-lucky \
  luci-app-lucky "$LUCKY_VERSION" "$PKG_DIR/lucky-suite"

export_source_subdir vernesong/OpenClash \
  OpenClash "$OPENCLASH_VERSION" luci-app-openclash \
  "$PKG_DIR/luci-app-openclash"

# ---------- 无现代 Release：固定 dated snapshot，同样只下载 tarball ----------
export_source_subdir lisaac/luci-app-diskman \
  luci-app-diskman "$DISKMAN_SOURCE_REF" applications/luci-app-diskman \
  "$PKG_DIR/luci-app-diskman"

export_source_subdir coolsnowwolf/luci \
  lean-luci "$CIFS_MOUNT_SOURCE_REF" applications/luci-app-cifs-mount \
  "$PKG_DIR/luci-app-cifs-mount"

# standalone 后修正 LuCI include 路径。
CIFS_MAKEFILE="$PKG_DIR/luci-app-cifs-mount/Makefile"
if grep -q '^include ../../luci.mk$' "$CIFS_MAKEFILE"; then
  sed -i 's#^include ../../luci.mk$#include $(TOPDIR)/feeds/luci/luci.mk#' "$CIFS_MAKEFILE"
fi

# 使用 rufengsuixing 的经典 LuCI 管理界面，由插件在线管理 AdGuardHome Core。
# 固定 commit，并应用 OpenWrt 25.12（apk）兼容补丁。
export_source_tree rufengsuixing/luci-app-adguardhome \
  luci-app-adguardhome "$ADGUARDHOME_LUCI_SOURCE_REF" \
  "$PKG_DIR/luci-app-adguardhome"
patch -d "$PKG_DIR/luci-app-adguardhome" -p1 \
  < "$ROOT_DIR/patches/luci-app-adguardhome-openwrt-25.12.patch"

# feeds 中有同名官方 LuCI 包；移除它的安装链接，确保只扫描自定义实现。
rm -f "$OPENWRT_DIR/package/feeds/luci/luci-app-adguardhome"

# 增量构建可能遗留版本号更高的官方 LuCI APK，apk 会优先选择它并重新拉入
# 官方 adguardhome Core。仅删除 luci feed 输出目录里的这个同名旧包。
find "$OPENWRT_DIR/bin/packages" -type f \
  -path '*/luci/luci-app-adguardhome-*.apk' -delete 2>/dev/null || true

export_source_subdir sbwml/openwrt_pkgs \
  sbwml-openwrt-pkgs "$RTP2HTTPD_SOURCE_REF" rtp2httpd \
  "$PKG_DIR/rtp2httpd"
export_source_subdir sbwml/openwrt_pkgs \
  sbwml-openwrt-pkgs "$RTP2HTTPD_SOURCE_REF" luci-app-rtp2httpd \
  "$PKG_DIR/luci-app-rtp2httpd"


# ---------- 本地自有包：M78 Accelerator x86_64 ----------
# 包源由 scripts/import-m78-ipk.sh 从原始 IPK 精简生成。
M78_LOCAL="$ROOT_DIR/packages/m78-x86"
if [[ -d "$M78_LOCAL" ]]; then
  rm -rf "$PKG_DIR/luci-app-m78accelerator"
  cp -a "$M78_LOCAL" "$PKG_DIR/luci-app-m78accelerator"
fi

echo
echo "Third-party packages prepared."
echo "Persistent source cache: $SOURCE_CACHE_DIR"
