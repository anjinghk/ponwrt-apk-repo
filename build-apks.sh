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

echo "==> [1/5] 配置 feeds（ponwrt 官方 7 源 + lucky 第三方源）"
cp feeds.conf.default feeds.conf
# lucky 源（提供 lucky 主程序 + luci-app-lucky + 中文包），用 aarch64 预编译核心
if ! grep -q '^src-git lucky ' feeds.conf; then
    echo 'src-git lucky https://github.com/gdy666/luci-app-lucky.git' >> feeds.conf
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
CONFIG_PACKAGE_tailscale=y
CONFIG_PACKAGE_luci-app-tailscale-community=y
CONFIG_PACKAGE_luci-i18n-tailscale-community-zh-cn=y
CONFIG_PACKAGE_luci-proto-wireguard=y
CONFIG_PACKAGE_wireguard-tools=y
CONFIG_PACKAGE_lucky=y
CONFIG_PACKAGE_luci-app-lucky=y
CONFIG_PACKAGE_luci-i18n-lucky-zh-cn=y
EOF
make defconfig

echo "==> [3/5] 确认目标包已被选中（应全部 =y）"
grep -E '^CONFIG_PACKAGE_(adguardhome|luci-app-adguardhome|tailscale|luci-app-tailscale-community|luci-i18n-tailscale-community-zh-cn|luci-proto-wireguard|wireguard-tools|lucky|luci-app-lucky|luci-i18n-lucky-zh-cn)=y' .config || true

echo "==> [4/5] 下载源码包并编译"
make -j"$JOBS" download
make -j"$JOBS"

echo "==> [5/5] 收集所有生成的 apk（主包 + 依赖 + 中文）"
mkdir -p "$SELF/out"
find bin/packages -type f -name '*.apk' -exec cp -v {} "$SELF/out/" \;
echo "共收集 $(find "$SELF/out" -name '*.apk' | wc -l) 个 apk 到 $SELF/out/"
ls -lh "$SELF/out/" | head -40
