#!/bin/bash
#
# File name: diy-part2.sh
# Description: 红米AX6云编译 OpenClash，VIKINGYFY main高通专用满血NSS分支

# ==============================================
# 1. 安装基础依赖
# ==============================================
echo "===== Step 1: Install basic dependencies ====="
sudo apt update -y
sudo apt install -y build-essential clang flex bison g++ gawk gcc-multilib g++-multilib \
                    gettext git libncurses5-dev libssl-dev python3-distutils rsync unzip zlib1g-dev \
                    file wget libfuse-dev curl

# ==============================================
# 2. 升级Golang到 27.x (Go1.27，适配xray-core)
# ==============================================
echo -e "\n===== Step 2: Upgrade Golang to 27.x ====="
rm -rf feeds/packages/lang/golang
git clone --depth=1 https://github.com/sbwml/packages_lang_golang -b 27.x feeds/packages/lang/golang

# ==============================================
# 3. 删除旧OpenClash包，防止残留冲突
# ==============================================
echo -e "\n===== Step 3: Remove old OpenClash packages ====="
rm -rf feeds/luci/applications/luci-app-openclash
rm -rf package/luci-app-openclash
rm -rf package/feeds/luci/luci-app-openclash

# ==============================================
# 4. 拉取最新 OpenClash
# ==============================================
echo -e "\n===== Step 4: Clone latest OpenClash ====="
git clone --depth=1 --single-branch https://github.com/vernesong/OpenClash.git package/luci-app-openclash
if [ -d "package/luci-app-openclash" ]; then
    echo "OPENCLASH_DOWNLOAD_CORE := false" >> package/luci-app-openclash/Makefile
    echo "✅ OpenClash 克隆成功，关闭编译阶段内核自动下载"
else
    echo "❌ OpenClash clone failed!"
    exit 1
fi

# ==============================================
# 5. 配置 & 解决各类包冲突
# ==============================================
echo -e "\n===== Step 5: Configure OpenClash & Fix Conflicts ====="
echo "CONFIG_PACKAGE_luci-app-openclash=y" >> .config

# --- 修复 python3 _ctypes 缺 ffi.h ---
# 本高通裁剪分支环境没有外部 libffi 包（CONFIG_PACKAGE_libffi 是无效符号，defconfig 会丢弃）。
# python3 Makefile 里的 --with-system-ffi 强制用外部 ffi 编 _ctypes，缺 ffi.h 直接 fatal。
# 去掉该强制开关后，configure 会把 _ctypes 当作缺失可选模块自动跳过，不再编译报错。
PY3MK="feeds/packages/lang/python/python3/Makefile"
if [ -f "$PY3MK" ]; then
    sed -i 's/--with-system-ffi//' "$PY3MK"
    echo "✅ 已去掉 python3 的 --with-system-ffi，跳过 _ctypes（无外部 libffi）"
    grep -n "system-ffi" "$PY3MK" || echo "   确认：Makefile 中已无 --with-system-ffi"
else
    echo "⚠️ 未找到 $PY3MK，跳过 ffi 修复"
fi

# dnsmasq 冲突，使用dnsmasq-full
sed -i 's/CONFIG_PACKAGE_dnsmasq=y/# CONFIG_PACKAGE_dnsmasq is not set/g' .config
echo "# CONFIG_PACKAGE_dnsmasq is not set" >> .config

# wpad 冲突处理
sed -i 's/CONFIG_PACKAGE_wpad-basic=y/# CONFIG_PACKAGE_wpad-basic is not set/g' .config
sed -i 's/CONFIG_PACKAGE_wpad-basic-mbedtls=y/# CONFIG_PACKAGE_wpad-basic-mbedtls/g' .config
echo "# CONFIG_PACKAGE_wpad-basic is not set" >> .config
echo "# CONFIG_PACKAGE_wpad-basic-mbedtls is not set" >> .config

# ath11k ddwrt 固件冲突
sed -i 's/CONFIG_PACKAGE_ath11k-firmware-ipq8074-ddwrt=y/# CONFIG_PACKAGE_ath11k-firmware-ipq8074-ddwrt/g' .config
echo "# CONFIG_PACKAGE_ath11k-firmware-ipq8074-ddwrt is not set" >> .config

# ==============================================
# 6. 修改默认网关IP 192.168.11.1
# ==============================================
echo -e "\n===== Step 6: Modify default IP ====="
sed -i 's/192.168.1.1/192.168.11.1/g' package/base-files/files/bin/config_generate

# ==============================================
# 7. 刷新defconfig，配置全部生效
# ==============================================
echo -e "\n===== Step 7: Refresh config dependencies ====="
make defconfig

# ==============================================
# 提示信息
# ==============================================
cat << EOF
===== DIY completed! =====
✅ VIKINGYFY main高通专用分支，满血NSS ECM补丁已加载，无线正常可用
✅ 修复qca-nss-ecm conntrack notifier API报错
✅ libbpf GCC14警告阻断修复
✅ Golang 升级到 1.27，适配新版xray-core
✅ OpenClash最新版，关闭编译阶段内核下载
✅ 已去掉 --with-system-ffi，跳过 _ctypes（本环境无 libffi 包）
✅ 默认IP：192.168.11.1
刷入后SSH执行安装mihomo内核：
---------------------------------------------------
mkdir -p /etc/openclash/core && cd /etc/openclash/core && \\
rm -rf clash_meta mihomo.tar.gz && \\
curl -L --retry 3 https://cdn.jsdelivr.net/gh/MetaCubeX/mihomo-release@main/latest/mihomo-linux-aarch64.tar.gz -o mihomo.tar.gz && \\
tar zxvf mihomo.tar.gz && mv mihomo clash_meta && chmod +x clash_meta && \\
/etc/init.d/openclash restart
---------------------------------------------------
EOF
