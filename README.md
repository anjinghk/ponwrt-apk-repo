# PonWrt 可选插件 apk 仓库（XG-040G-MD）

为 **Nokia XG-040G-MD**（AN7581，架构 `aarch64_cortex-a53`）准备的**可选插件 apk 包**。

固件本身保持干净，这些是**需要时再手动安装**的插件，不进固件。

## 为什么单独做这个仓库

- 你的 PonWrt 用 **apk** 包管理器（不是 opkg/ipk）。
- 这些包用 **pbs05/ponwrt 同一套源码和 feeds 编译**，架构、依赖、版本与固件同源，比拿第三方现成包可靠。
- 全部为 `aarch64_cortex-a53` 架构，与你的设备匹配。

## 包含哪些插件

| 插件 | 说明 | 中文 |
|---|---|---|
| AdGuard Home | DNS 广告过滤 | ✅ 主程序界面自带中文；LuCI 集成壳中文包已补 |
| Tailscale | WireGuard 组网的异地组网工具 | ✅ luci 中文包 |
| WireGuard | 高性能 VPN | LuCI 协议界面自带中文 |
| Lucky（大吉） | 反向代理、DDNS、IPv6 转发等 | ✅ 中文包 |
| iStore 商店 | 图形化应用商店（仅商店本体，不含其它 iStore 应用） | ✅ 界面自带中文 |
| omcproxy | IGMPv3 / MLDv2 组播代理（轻量级，比 igmpproxy 更稳） | ✅ LuCI 界面 + 中文包 |

## 怎么安装

1. 到本仓库 [Releases](https://github.com/anjinghk/ponwrt-apk-repo/releases) 下载 `ponwrt-apk-aarch64_cortex-a53.tar.gz`。
2. 解压，把里面**所有** `.apk` 文件上传到路由器的 `/tmp` 目录。
3. SSH 登录路由器，执行：

```sh
cd /tmp
apk add --allow-untrusted ./*.apk
/etc/init.d/rpcd reload
/etc/init.d/uhttpd reload
```

> **为什么不能用网页「系统 → 软件包」直接上传？**
> 第三方/自编译 apk 没有官方签名，网页上传会报 `UNTRUSTED` 错误。必须用上面的 SSH 命令加 `--allow-untrusted`。

4. 刷新 LuCI 页面，在对应菜单里就能看到插件了。

## 依赖

Release 里的压缩包包含编译产出的**全部 apk**（目标插件 + 自动解析的依赖 + 中文包）。安装时 `apk add ./*.apk` 会一次性装齐。如果某个依赖在固件里已经有了，apk 会自动跳过。

## 重新编译

点本仓库 Actions 里的「编译 PonWrt 可选插件 apk 包」→「Run workflow」即可。流程：

1. 拉取 `pbs05/ponwrt` 主线 + 官方 feeds + lucky / istore 第三方源；
2. 基于 `configs/an7581.config` 生成最小 `.config`，只选这几个插件，`make defconfig` 自动解析依赖；
3. `make` 编译后收集 `bin/packages/aarch64_cortex-a53/` 下全部 apk；
4. 打包发布到 Release。

编译脚本见 [`build-apks.sh`](build-apks.sh)。

## 注意事项

- 包由 25.12 阶段的 ponwrt 源码编译。若你的固件源码版本相差很大，个别依赖可能有版本差异；以实际安装结果为准。
- 安装第三方插件后如出现问题，可 `apk del <包名>` 卸载。
- Lucky 的预编译核心来自 `gdy666/luci-app-lucky`，按 `aarch64` 自动选 `arm64` 版本，与本机架构匹配。
- iStore 商店来自 `linkease/istore`，只编译 `luci-app-store` 本体及其必需依赖（luci-lib-taskd / luci-lib-xterm / taskd），**不含** DDNSTO、易有云等其它 iStore 应用。商店装好后需在 LuCI 里出现「iStore」菜单才能用。
- omcproxy 主程序来自 ponwrt 主线自带包（`package/network/services/omcproxy`），LuCI 界面与中文包来自 `immortalwrt/luci`。用于 IPTV 组播代理（比老旧的 igmpproxy 更稳定），装好后在 LuCI「网络 - omcproxy」里配置。
