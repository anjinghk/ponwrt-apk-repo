#!/usr/bin/env bash
# ==============================================================================
# 在 ponwrt 源码根目录运行：只编译几个可选插件的 .apk 包（含全部依赖）
# 目标设备：Nokia XG-040G-MD / AN7581，架构 aarch64_cortex-a53
# 固件本身不变；这里只产出可手动安装的 apk 包
# ==============================================================================
set -euo pipefail

SRC="${1:-$PWD}"
SELF="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JOBS="${JOBS:-2}"

cd "$SRC"
[ -x scripts/feeds ] || { echo "错误：$SRC 不是 ponwrt 源码根目录" >&2; exit 1; }

echo "==> [1/5] 配置 feeds（ponwrt 官方源 + lucky + istore 第三方源）"
cp feeds.conf.default feeds.conf
# lucky 源（提供 lucky 主程序 + luci-app-lucky + 中文包），用 aarch64 预编译核心
if ! grep -q '^src-git lucky ' feeds.conf; then
    echo 'src-git lucky https://github.com/gdy666/luci-app-lucky.git' >> feeds.conf
fi
# istore 源（只取 luci-app-store 商店本体，不装 iStore 其它应用）
if ! grep -q '^src-git istore ' feeds.conf; then
    echo 'src-git istore https://github.com/linkease/istore.git;main' >> feeds.conf
fi
./scripts/feeds update -a
./scripts/feeds install -a

echo "==> [2/5] 生成最小 .config（基于 an7581.config，只选目标插件）"
cp configs/an7581.config .config
# 关掉所有目标设备，避免编译固件镜像；只留一个占位 device（满足 defconfig 校验）
python3 - <<'PY'
import re
lines=open('.config',encoding='utf-8').read().splitlines()
out=[]
for l in lines:
    m=re.match(r'^CONFIG_TARGET_DEVICE_airoha_an7581_DEVICE_(.+)=y$',l)
    if m:
        out.append('# CONFIG_TARGET_DEVICE_airoha_an7581_DEVICE_%s is not set'%m.group(1))
    else:
        out.append(l)
open('.config','w',encoding='utf-8').write('\n'.join(out)+'\n')
PY
# 追加目标包（defconfig 会自动把依赖一起选中）
cat >> .config <<'EOF'
CONFIG_PACKAGE_adguardhome=y
CONFIG_PACKAGE_luci-app-adguardhome=y
CONFIG_PACKAGE_luci-i18n-adguardhome-zh-cn=y
CONFIG_PACKAGE_tailscale=y
CONFIG_PACKAGE_luci-app-tailscale-community=y
CONFIG_PACKAGE_luci-i18n-tailscale-community-zh-cn=y
CONFIG_PACKAGE_luci-proto-wireguard=y
CONFIG_PACKAGE_wireguard-tools=y
CONFIG_PACKAGE_lucky=y
CONFIG_PACKAGE_luci-app-lucky=y
CONFIG_PACKAGE_luci-i18n-lucky-zh-cn=y
# iStore 商店本体（defconfig 会自动带出必要依赖 luci-lib-taskd/taskd，
# 不选取 DDNSTO、易有云等 iStore 其它应用）
CONFIG_PACKAGE_luci-app-store=y
# omcproxy：IGMPv3/MLDv2 组播代理（ponwrt 主线自带）+ LuCI 界面 + 中文包
CONFIG_PACKAGE_omcproxy=y
CONFIG_PACKAGE_luci-app-omcproxy=y
CONFIG_PACKAGE_luci-i18n-omcproxy-zh-cn=y
EOF
make defconfig

echo "==> [3/5] 确认目标包已被选中（应全部 =y）"
grep -E '^CONFIG_PACKAGE_(adguardhome|luci-app-adguardhome|luci-i18n-adguardhome-zh-cn|tailscale|luci-app-tailscale-community|luci-i18n-tailscale-community-zh-cn|luci-proto-wireguard|wireguard-tools|lucky|luci-app-lucky|luci-i18n-lucky-zh-cn|luci-app-store|omcproxy|luci-app-omcproxy|luci-i18n-omcproxy-zh-cn)=y' .config || true

echo "==> [4/5] 下载源码包并完整编译"
make -j"$JOBS" download
# 必须跑完整 world：它会先编译工具链和 host 工具（lua 等），只跑 package/compile
# 会因 host 工具缺失而失败。world 末尾的 json_overview_image_info 需要 device/profile
# 生成镜像信息，而我们已关掉所有 device，这一步必然失败——但此时所有 apk 已生成到
# bin/packages，因此容忍这最后一步失败，靠下面的包齐全性检查兜底。
make -j"$JOBS" || echo "==> 注意：world 末尾镜像信息步骤预期失败（未选 device），apk 应已生成，继续检查"

echo "==> [5/5] 收集所有生成的 apk（主包 + 依赖 + 中文）"
mkdir -p "$SELF/out"
find bin/packages -type f -name '*.apk' -exec cp -v {} "$SELF/out/" \;
CNT=$(find "$SELF/out" -name '*.apk' | wc -l)
echo "共收集 $CNT 个 apk 到 $SELF/out/"
if [ "$CNT" -eq 0 ]; then
    echo "错误：bin/packages 下没有生成任何 apk" >&2
    exit 1
fi
echo "=== 确认目标包与中文包都在 ==="
for key in adguardhome luci-app-adguardhome luci-i18n-adguardhome-zh-cn \
           tailscale luci-app-tailscale-community luci-i18n-tailscale-community-zh-cn \
           wireguard-tools luci-proto-wireguard \
           lucky luci-app-lucky luci-i18n-lucky-zh-cn \
           omcproxy luci-app-omcproxy luci-i18n-omcproxy-zh-cn \
           luci-app-store luci-lib-taskd luci-lib-xterm taskd; do
    if ls "$SELF/out/${key}"-*.apk >/dev/null 2>&1; then
        echo "  OK   $key"
    else
        echo "  缺失 $key"
    fi
done
ls -lh "$SELF/out/" | head -60
