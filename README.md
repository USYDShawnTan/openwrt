# Xiaotan OpenWrt 本地构建版 v4.5.1

目标：**稳定、可重复、版本易懂，并减少重复访问 GitHub。**

底座保持 OpenWrt 官方稳定 Release，不维护 OpenWrt 整树 fork；自定义只放在构建脚本、第三方包和少量 patch 上。

## 当前仓库状态（2026-09-23）

- 本仓库管理 `scripts/`、`config/`、`files/`、`patches/` 和 `versions.env`，不包含 OpenWrt 源码整树、缓存、备份和固件产物。
- 已包含 rufengsuixing AdGuardHome 插件适配、Argon Config 的 APK/LuCI 兼容与中文修复，以及 FullCone 中文页面和旧 APK 残留处理。
- 软件流量卸载默认开启，硬件卸载默认关闭；FullCone 默认不启用，需要按实际执行 NAT 的出口区域配置。
- 默认密码按项目所有者要求保留在源码中。若以后推送仓库，密码会进入 Git 历史；之后修改密码不会删除历史记录。不要把它当作秘密或复用于其他服务。
- GitHub Actions 工作流见 `.github/workflows/build-openwrt.yml`：手动触发，准备依赖及固定版本源码，再调用现有构建脚本。
- 当前目标为 x86-64 EFI；其他架构和路由器型号需要重新选择 target/profile，不能直接使用本镜像。

## v4.5.1 变化

在 v4.5 的稳定布局基础上，主要修复第三方源码下载方式：

- 不再使用 `git clone --mirror`。
- OpenClash、Argon、Argon Config、EasyTier、Lucky 等 Release/Tag 直接下载 GitHub source tarball。
- DiskMan、CIFS Mount、rtp2httpd 包装层、SONiC FullCone 等 snapshot 同样下载固定 ref 的 tarball，不 clone 仓库历史。
- 持久化缓存改为：`~/openwrt-build/source-cache/`。
- 下载使用 `curl` 自动重试；失败的 `.part` 文件下次会尝试续传。
- 支持可选 `GITHUB_PROXY_PREFIX`，默认不使用任何第三方代理。
- ZIP 内 `scripts/*.sh` 已带可执行权限，正常以 `xiaotan` 用户解压后不需要再 `chmod +x`。
- 构建开始前检查工程目录、OpenWrt 源码目录和 source-cache 是否对当前用户可写，提前发现 `root:root` 权限问题。

## 整体架构

```text
OpenWrt v25.12.5 官方 Release
│
├─ 官方 feeds
├─ firewall4 / nftables
├─ Flow Offloading        OpenWrt 原生
├─ kmod-tcp-bbr           OpenWrt 官方
├─ SONiC FullCone         固定 2026-08-15 snapshot
├─ AdGuard Home           rufengsuixing LuCI 插件（核心由插件管理）
├─ OpenClash              v0.47.156
├─ EasyTier               v2.6.4
├─ Lucky                  v2.27.2
└─ Argon                  v2.4.6
```

Turbo ACC 已删除。Fast Classifier / Shortcut-FE / Broadcom FullCone 的选择逻辑也不再存在。

## 版本表

日常升级只需要优先看：

```text
versions.env
```

当前：

```text
OpenWrt          v25.12.5
Argon            v2.4.6
Argon Config     v0.9
EasyTier         v2.6.4
Lucky            v2.27.2
OpenClash        v0.47.156
DiskMan          0.2.13 snapshot
CIFS Mount       1-r7 snapshot
rtp2httpd        3.14.2
SONiC FullCone   2026-08-15 snapshot
```

有 Release / Tag 的组件使用人类可读版本号。只有没有合适现代 Release 的 snapshot，底层 ref 才放在：

```text
scripts/source-locks.sh
```

平时不需要改这个文件。

## 源码缓存

第三方源码缓存目录：

```text
~/openwrt-build/source-cache/
```

第一次：

```text
GitHub codeload
   ↓
<tag/ref>.tar.gz
   ↓
~/openwrt-build/source-cache
```

以后版本不变：

```text
source cache hit
   ↓
直接解压
   ↓
不访问 GitHub
```

这和 OpenWrt 自己的缓存是分开的：

```text
~/openwrt-build/openwrt/dl
~/openwrt-build/openwrt/.ccache
~/openwrt-build/openwrt/build_dir
~/openwrt-build/openwrt/staging_dir
```

### 网络不稳定

下载默认带多次重试。如果所在网络访问 GitHub codeload 不稳定，也可以临时指定一个自己信任的 HTTP 前缀代理：

```bash
export GITHUB_PROXY_PREFIX='https://your-proxy.example/'
```

脚本会把它加在原始 `https://codeload.github.com/...` URL 前。默认值为空，不主动使用第三方代理。

## 权限规范

整个构建链建议只使用普通用户 `xiaotan`：

```text
/home/xiaotan/openwrt-build              xiaotan:xiaotan
/home/xiaotan/openwrt-build/openwrt      xiaotan:xiaotan
/home/xiaotan/openwrt-build/source-cache xiaotan:xiaotan
/home/xiaotan/xiaotan-openwrt-local-v4.5.1  xiaotan:xiaotan
```

如果之前用 root 解压或构建过，先一次性修正：

```bash
sudo chown -R xiaotan:xiaotan ~/openwrt-build
sudo chown -R xiaotan:xiaotan ~/xiaotan-openwrt-local-v4.5.1
```

以后不要使用：

```bash
sudo unzip ...
sudo ./scripts/build-local.sh ...
sudo make ...
```

正常以 `xiaotan` 用户解压即可，ZIP 中脚本已经是 executable。

## 从旧 Turbo ACC 源码树迁移

当前 `~/openwrt-build/openwrt` 如果以前跑过 Turbo ACC，不需要 `make distclean`。

v4.5.1 会恢复 Turbo ACC / 旧 FullCone 涉及的这些源码区域：

```text
target/linux/generic
package/libs/libnftnl
package/network/config/firewall
package/network/config/firewall4
package/network/utils/iptables
package/network/utils/nftables
package/turboacc
```

然后重新应用 SONiC FullCone。

不会主动删除：

```text
dl/
.ccache/
build_dir/
staging_dir/
```

因此仍然可以利用增量构建缓存。

## 默认值

- LAN：`192.168.12.199/24`
- Gateway / DNS：`192.168.12.1`
- DHCPv4 / DHCPv6 / RA：关闭
- root 默认密码：`coolopenwrt`
- LuCI：简体中文
- Argon 默认主题
- RootFS：`1024 MiB`

## 当前功能

- Argon + Argon Config
- ttyd / DiskMan
- CIFS Mount / Samba4
- EasyTier
- rufengsuixing AdGuardHome LuCI 插件（已适配当前固件）
- Lucky
- OpenClash
- OpenWrt 原生 Flow Offloading
- OpenWrt 官方 BBR
- SONiC FullCone
- UPnP / WOL
- rtp2httpd

## 构建

确保 ZIP 是以 `xiaotan` 用户解压：

```bash
cd ~
unzip xiaotan-openwrt-local-v4.5.1.zip
cd ~/xiaotan-openwrt-local-v4.5.1
```

脚本已带执行权限，直接：

```bash
./scripts/build-local.sh ~/openwrt-build/openwrt
```

OpenWrt 源码必须 checkout 在：

```text
v25.12.5
```

最终产物：

```text
dist/openwrt-x86-64-generic-squashfs-combined-efi.img.gz
```

## GitHub Actions 编译

在仓库 **Actions → Build OpenWrt x86-64 → Run workflow** 手动启动。
推送代码不会自动触发编译。工作流使用 Ubuntu 24.04、2 个编译任务，最长运行 6 小时。

工作流从 `versions.env` 读取 OpenWrt 版本，复用 `scripts/build-local.sh` 和所有补丁；不会依赖 WSL 的已有缓存。首次云端构建耗时取决于 Runner、下载速度和依赖编译，尚需实际运行验证。

成功后在运行页面的 Artifacts 下载原始 `.img`、压缩版 `.img.gz`、Hyper-V `.vhdx`、包清单、完整配置及 SHA256 校验文件；日志单独上传。产物默认保留 14 天，不自动创建 Release。

VHDX 会进行格式检查及 RAW 内容一致性验证，但不代表已经完成 Hyper-V 启动测试。默认密码仍包含在固件里，供自用测试；部署后请修改。

## FullCone 配置

SONiC FullCone 集成到原生 firewall4/nftables/LuCI Firewall，不再使用 Turbo ACC 页面。

建议：

```text
Flow Offloading   ON
Hardware Offload  OFF（普通 x86 / Hyper-V 默认不需要）
FullCone          全局开关 + 实际 NAT 出口区域开关，且该区域开启地址伪装
FullCone proto    游戏/P2P 场景可只开 UDP
```

常规主路由的出口通常是 WAN。单臂旁路由的出口可能是 LAN，但不要仅为开启 FullCone 而增加一层 NAT；只提供 DNS 或不执行 NAT 时，该功能不适用。旁路由的 FullCone 不能消除主路由或运营商上游的 NAT 限制。

## 以后怎么升级

例如 OpenClash：

```bash
OPENCLASH_VERSION=v0.47.156
```

未来有新的正式 Release，只改成：

```bash
OPENCLASH_VERSION=v0.47.xxx
```

然后重新构建 → Hyper-V 验证 → 再把它认定为你的稳定版本。

OpenWrt 大版本或小版本升级建议单独开新的 Xiaotan 工程版本，并重新验证 SONiC FullCone、OpenClash、EasyTier、AdGuard Home 和 LuCI。
