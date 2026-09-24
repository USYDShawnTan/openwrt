#!/usr/bin/env bash
set -euo pipefail

OPENWRT_DIR="${1:?usage: select-packages.sh <openwrt-dir>}"
cd "$OPENWRT_DIR"

# ============================================================
# 插件选择清单
# ============================================================
# 想“加入一个软件包”：cfg_e PACKAGE_包名
# 想“明确禁用一个软件包”：cfg_d PACKAGE_包名
# 修改完重新执行 build-local.sh 即可。
#
# 这里直接修改 .config，然后由 make defconfig 自动解析依赖。

cfg_e() {
  local key="CONFIG_$1"
  sed -i -e "/^${key}=/d" -e "/^# ${key} is not set$/d" .config
  printf '%s=y\n' "$key" >> .config
}

cfg_d() {
  local key="CONFIG_$1"
  sed -i -e "/^${key}=/d" -e "/^# ${key} is not set$/d" .config
  printf '# %s is not set\n' "$key" >> .config
}

# ---------- LuCI 基础 ----------
cfg_e PACKAGE_luci
cfg_e PACKAGE_luci-ssl
# 一些第三方老 LuCI 插件仍依赖 Lua/compat 兼容层。
cfg_e PACKAGE_luci-compat
cfg_e PACKAGE_luci-lua-runtime
cfg_e LUCI_LANG_zh_Hans
cfg_e PACKAGE_luci-i18n-base-zh-cn
# LuCI 核心常用页面中文。
cfg_e PACKAGE_luci-i18n-firewall-zh-cn
cfg_e PACKAGE_luci-i18n-package-manager-zh-cn

# ---------- 主题 ----------
cfg_e PACKAGE_luci-theme-argon
cfg_e PACKAGE_luci-app-argon-config
cfg_e PACKAGE_luci-i18n-argon-config-zh-cn

# ---------- 管理工具 ----------
# LuCI 浏览器终端。
cfg_e PACKAGE_luci-app-ttyd
cfg_e PACKAGE_luci-i18n-ttyd-zh-cn

# ---------- 磁盘 / SMB ----------
cfg_e PACKAGE_luci-app-diskman
cfg_e PACKAGE_luci-i18n-diskman-zh-cn
# 挂载别人的 SMB/CIFS 共享。
cfg_e PACKAGE_luci-app-cifs-mount
cfg_e PACKAGE_luci-i18n-cifs-mount-zh-cn
# 把 OpenWrt 自己的目录通过 Samba 分享出去。
cfg_e PACKAGE_luci-app-samba4
cfg_e PACKAGE_luci-i18n-samba4-zh-cn

# ---------- EasyTier ----------
# easytier-noweb 会把 x86_64 EasyTier core/cli 一起编进固件。
cfg_e PACKAGE_easytier-noweb
cfg_e PACKAGE_luci-app-easytier
cfg_e PACKAGE_luci-i18n-easytier-zh-cn

# ---------- DNS / 服务 ----------
# 使用 rufengsuixing/luci-app-adguardhome，由 LuCI 页面下载和管理 Core。
# 禁用 OpenWrt feeds 的官方 Core，避免把另一套实现一起编进固件。
cfg_d PACKAGE_adguardhome
cfg_e PACKAGE_luci-app-adguardhome

# Lucky 自带 DDNS/反代/证书等功能，因此不再编 luci-app-ddns / ddns-scripts。
cfg_e PACKAGE_lucky
cfg_e PACKAGE_luci-app-lucky
cfg_e PACKAGE_luci-i18n-lucky-zh-cn
cfg_d PACKAGE_luci-app-ddns
cfg_d PACKAGE_ddns-scripts

# ---------- OpenClash ----------
# OpenClash 需要 dnsmasq-full，并使用 LuCI 兼容层。
cfg_d PACKAGE_dnsmasq
cfg_e PACKAGE_dnsmasq-full
cfg_e PACKAGE_luci-app-openclash

# ---------- 网络加速 ----------
# Flow Offloading 是 OpenWrt/firewall4 原生功能，由 uci-defaults 开启。
# BBR 使用 OpenWrt 官方 kmod-tcp-bbr。
cfg_e PACKAGE_kmod-tcp-bbr

# FullCone 由 openwrt-sonic-fullcone patch 集成进原生 firewall4/nftables，

# ---------- 局域网工具 ----------
cfg_e PACKAGE_luci-app-upnp
cfg_e PACKAGE_luci-i18n-upnp-zh-cn
cfg_e PACKAGE_luci-app-wol
cfg_e PACKAGE_luci-i18n-wol-zh-cn

# ---------- IPTV ----------
# rtp2httpd 自己即可完成 RTP/UDP/RTSP -> HTTP，不需要 FFmpeg。
cfg_e PACKAGE_rtp2httpd
cfg_e PACKAGE_luci-app-rtp2httpd
cfg_e PACKAGE_luci-i18n-rtp2httpd-zh-cn
cfg_d PACKAGE_ffmpeg

# ---------- M78 Accelerator ----------
# 只在 x86_64 主程序已经通过 import-m78-ipk.sh 导入时启用，
# 避免仓库尚未 vendoring 二进制时影响正常固件构建。
M78_BIN="package/xiaotan/luci-app-m78accelerator/files/usr/bin/netflow_x86_64"
if [[ -f "$M78_BIN" ]]; then
  cfg_e PACKAGE_luci-app-m78accelerator
  M78_ENABLED=1
else
  cfg_d PACKAGE_luci-app-m78accelerator
  M78_ENABLED=0
  echo "M78 Accelerator: 未发现 x86_64 二进制，跳过；运行 scripts/import-m78-ipk.sh 后会自动启用。"
fi

# ---------- 25.12 软件包管理 ----------
cfg_e PACKAGE_luci-app-package-manager
# 旧版 opkg LuCI 不再使用。
cfg_d PACKAGE_luci-app-opkg

# 让 OpenWrt 根据上述选择补齐依赖并规范化 .config。
make defconfig

# ---------- 关键软件包校验 ----------
# 如果第三方源码路径/版本不兼容，make defconfig 可能会自动丢掉符号。
# 在正式编译前先检查，报错会更容易看懂。
required=(
  PACKAGE_luci
  PACKAGE_luci-ssl
  PACKAGE_luci-theme-argon
  PACKAGE_luci-app-argon-config
  PACKAGE_luci-app-ttyd
  PACKAGE_luci-app-diskman
  PACKAGE_luci-app-cifs-mount
  PACKAGE_luci-app-samba4
  PACKAGE_easytier-noweb
  PACKAGE_luci-app-easytier
  PACKAGE_luci-app-adguardhome
  PACKAGE_lucky
  PACKAGE_luci-app-lucky
  PACKAGE_dnsmasq-full
  PACKAGE_luci-app-openclash
  PACKAGE_kmod-tcp-bbr
  PACKAGE_luci-app-upnp
  PACKAGE_luci-app-wol
  PACKAGE_rtp2httpd
  PACKAGE_luci-app-rtp2httpd
)

if [[ "${M78_ENABLED:-0}" == "1" ]]; then
  required+=(PACKAGE_luci-app-m78accelerator)
fi

missing=()
for sym in "${required[@]}"; do
  if ! grep -q "^CONFIG_${sym}=y$" .config; then
    missing+=("$sym")
  fi
done

if ((${#missing[@]})); then
  echo >&2
  echo "ERROR: 以下软件包在 make defconfig 后没有成功启用：" >&2
  printf '  - %s\n' "${missing[@]}" >&2
  echo >&2
  echo "通常是第三方源码版本、路径或当前 OpenWrt 版本不兼容。" >&2
  exit 11
fi

echo "已启用的 Xiaotan 主要软件包："
grep -E '^CONFIG_PACKAGE_(luci-theme-argon|luci-app-argon-config|luci-app-ttyd|luci-app-diskman|luci-app-cifs-mount|luci-app-samba4|easytier-noweb|luci-app-easytier|adguardhome|luci-app-adguardhome|lucky|luci-app-lucky|luci-app-openclash|luci-app-m78accelerator|kmod-tcp-bbr|luci-app-upnp|luci-app-wol|rtp2httpd|luci-app-rtp2httpd|dnsmasq-full)=y
 .config || true
