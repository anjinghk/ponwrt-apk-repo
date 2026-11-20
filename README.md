# PonWrt 可选插件 apk 包（XG-040G-MD）

为 **Nokia XG-040G-MD**（AN7581，架构 `aarch64_cortex-a53`）准备的**可选插件 apk 包**，从官方源直接拉取，**无需编译**。固件本身保持干净，这些是**需要时再手动安装**的插件。

## 包含哪些包

[Releases](https://github.com/anjinghk/ponwrt-apk-repo/releases) 里的 `ponwrt-apk-aarch64_cortex-a53.tar.gz` 包含 13 个 apk：

| 插件 | 包含的包 | 来源 |
|---|---|---|
| AdGuard Home | `adguardhome` + `luci-app-adguardhome` | ImmortalWrt 官方源 |
| Tailscale | `tailscale` + `luci-app-tailscale-community` + 中文包 | ImmortalWrt 官方源 |
| WireGuard | `wireguard-tools` + `luci-proto-wireguard` | ImmortalWrt 官方源 |
| omcproxy | `omcproxy` + `luci-app-omcproxy` + 中文包 | ImmortalWrt 官方源 |
| Lucky（大吉） | `lucky-3.8.1` + `luci-app-lucky` + 中文包 | FloatingDream528 第三方（aarch64_generic） |

AdGuard Home 的 LuCI 集成壳官方源只有老挝语包，没有 zh-cn；其主程序 Web 界面本身支持中文。

## 安装方法

SSH 登录路由器，把 Release 里的 tar.gz 下载并解压，进去执行：

```sh
cd /tmp
wget -O apk.tar.gz <Release 里 tar.gz 的下载地址>
tar -xzf apk.tar.gz
cd <解压目录>
apk add --allow-untrusted ./*.apk
/etc/init.d/rpcd reload
/etc/init.d/uhttpd reload
```

Lucky 也可以直接用包内自带的 `sh install-apk.sh` 一键装。

## ⚠️ 重要：版本兼容风险（务必先读）

这些包来自 **ImmortalWrt 官方 25.12-SNAPSHOT 源**，而你的固件是 **pbs05/ponwrt**（同基于 25.12 阶段，但源码/feeds 更新）。实测版本对比：

- 固件 LuCI 版本 `26.315.10273`（11 月），官方源 `26.298.29275`（10 月底）——**不一致**
- `firewall4`、`netifd`、`dnsmasq`、`busybox` 等核心包版本也都不同
- 官方源里**没有** `libc`（每个 OpenWrt 固件自带私有版本）

因此：

1. **独立主程序**（`adguardhome`、`tailscale`、`lucky` 主程序）——依赖较少，通常能直接装上，风险低。
2. **LuCI 界面包**（`luci-app-*`）——依赖 `luci-base`，版本对不上时 apk 可能尝试降级/替换核心组件。**若安装时 apk 提示要升级或替换大量基础包，请取消，不要强行装。**

如果 apk 报依赖错误，可尝试忽略依赖强制装（仅适合独立主程序，界面包慎用）：

```sh
apk add --allow-untrusted --force-depends ./adguardhome-*.apk ./tailscale-*.apk ./lucky-*.apk
```

**建议**：先只装主程序试，确认没问题再逐个装界面包。出问题可 `apk del <包名>` 卸载。

## 另一种装法：配置官方源在线装（依赖自动处理）

在路由器上把官方源加进去，让 apk 在线解析依赖：

```sh
cat >> /etc/apk/repositories.d/customfeeds.list <<'EOF'
https://downloads.immortalwrt.org/releases/25.12-SNAPSHOT/packages/aarch64_cortex-a53/base/packages.adb
https://downloads.immortalwrt.org/releases/25.12-SNAPSHOT/packages/aarch64_cortex-a53/luci/packages.adb
https://downloads.immortalwrt.org/releases/25.12-SNAPSHOT/packages/aarch64_cortex-a53/packages/packages.adb
https://downloads.immortalwrt.org/releases/25.12-SNAPSHOT/packages/aarch64_cortex-a53/routing/packages.adb
EOF
apk update
apk add adguardhome tailscale wireguard-tools omcproxy
```

之后也能在 LuCI「系统 → 软件包」里搜名字点安装。注意同样存在上面的版本兼容风险。

## 为什么不完全可靠

每个 OpenWrt/ImmortalWrt 固件的 libc、内核模块、基础库都是编译时生成的，**不同固件之间不通用**。官方现成包是按官方固件的依赖版本编的，装到 ponwrt 上版本可能对不上。最稳妥的永远是**用 ponwrt 同套源码编译**（本仓库 `.github/workflows/build-apks.yml` 保留了这套能力，随时可重新启用）。

## 文件

- `ponwrt-apk-aarch64_cortex-a53.tar.gz` — 13 个 apk + 安装脚本
- `packages/` — 解包后的单个 apk（供按需下载）
- `build-apks.sh` + `.github/workflows/build-apks.yml` — 同源编译脚本（备用，未启用）
