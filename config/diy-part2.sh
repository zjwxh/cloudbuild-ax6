#!/bin/bash
# File name: diy-part2.sh
# Description: 小米 AX3000T 云编译（OpenClash最新版 + MT7981驱动修复）

# ==============================================
# 1. 安装基础依赖
# ==============================================
echo "===== Step 1: Install basic dependencies ====="
sudo apt update -y
sudo apt install -y build-essential clang flex bison g++ gawk gcc-multilib g++-multilib \
                    gettext git libncurses5-dev libssl-dev python3-distutils rsync unzip zlib1g-dev \
                    file wget libfuse-dev curl

# ==============================================
# 2. 升级 feeds 中的 Golang 到 26.x
# ==============================================
echo -e "\n===== Step 2: Upgrade Golang to 26.x ====="
rm -rf feeds/packages/lang/golang
git clone --depth=1 https://github.com/sbwml/packages_lang_golang -b 26.x feeds/packages/lang/golang

# ==============================================
# 3. 删除旧的 OpenClash 包（防止冲突）
# ==============================================
echo -e "\n===== Step 3: Remove old OpenClash packages ====="
rm -rf feeds/luci/applications/luci-app-openclash
rm -rf package/luci-app-openclash
rm -rf package/feeds/luci/luci-app-openclash

# ==============================================
# 4. 克隆 OpenClash 最新版
# ==============================================
echo -e "\n===== Step 4: Clone latest OpenClash ====="
git clone --depth=1 --single-branch https://github.com/vernesong/OpenClash.git package/luci-app-openclash

if [ -d "package/luci-app-openclash" ]; then
    echo "OPENCLASH_DOWNLOAD_CORE := false" >> package/luci-app-openclash/Makefile
    echo "✅ OpenClash最新版克隆成功，已禁用内核自动下载"
else
    echo "❌ OpenClash克隆失败！"
    exit 1
fi

# ==============================================
# 5. 启用 OpenClash 编译开关
# ==============================================
echo -e "\n===== Step 5: Enable OpenClash compile switch ====="
echo "CONFIG_PACKAGE_luci-app-openclash=y" >> .config

# ==============================================
# 6. 修改默认 IP 为 192.168.31.1
# ==============================================
echo -e "\n===== Step 6: Modify default IP ====="
sed -i 's/192.168.1.1/192.168.31.1/g' package/base-files/files/bin/config_generate

# ==============================================
# 7. 终极修复：修正网卡驱动芯片 (MT7986 -> MT7981)
# ==============================================
echo -e "\n===== Step 7: Fix Wi-Fi Driver Chipset ====="
sed -i 's/CONFIG_MTK_CONNINFRA_APSOC_MT7986=y/# CONFIG_MTK_CONNINFRA_APSOC_MT7986 is not set/g' .config
sed -i 's/# CONFIG_MTK_CONNINFRA_APSOC_MT7981 is not set/CONFIG_MTK_CONNINFRA_APSOC_MT7981=y/g' .config
sed -i 's/CONFIG_first_card_name="MT7986"/CONFIG_first_card_name="MT7981"/g' .config
echo "✅ 网卡驱动已被强制修正为 MT7981！"

# 注意：这里删除了原先的 make clean，防止破坏 Github Actions 的编译环境！

# ==============================================
# 最终提示
# ==============================================
cat << EOF

===== DIY completed! =====
✅ 核心修复：无线驱动芯片已从 MT7986 强制更正为 MT7981，防崩溃重启！
✅ 已克隆 OpenClash master 分支最新版
✅ 默认 IP 已修改为：192.168.31.1
✅ 刷入固件后，SSH 登录执行以下命令安装最新 mihomo 内核 (已修正为 armv8 架构)：
---------------------------------------------------
mkdir -p /etc/openclash/core && cd /etc/openclash/core && \
rm -rf clash_meta mihomo.tar.gz && \
curl -L --retry 3 https://cdn.jsdelivr.net/gh/MetaCubeX/mihomo-release@main/latest/mihomo-linux-armv8.tar.gz -o mihomo.tar.gz && \
tar zxvf mihomo.tar.gz && mv mihomo clash_meta && chmod +x clash_meta && \
/etc/init.d/openclash restart
---------------------------------------------------
EOF
