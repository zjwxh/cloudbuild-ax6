#!/bin/bash
#
# Copyright (c) 2019-2024 Peter Repukat - FlatspotSoftware
# Copyright (c) 2021-2025 ImmortalWrt
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#
# File name: diy-part2.sh
# Description: ImmortalWrt DIY script part 2 (After Update feeds)
# 适配：红米AX6000 (hanwckf/immortalwrt-mt798x)
# 功能：Golang 26.x升级 + helloworld源集成 + OpenClash 0.4.7(Meta内核) + 默认IP修改为192.168.31.1

# ==============================================
# 1. 安装编译依赖（基础+Golang/OpenClash编译依赖）
# ==============================================
echo "===== Step 1: Install build dependencies ====="
sudo apt update -y
sudo apt full-upgrade -y
sudo apt install -y build-essential clang flex bison g++ gawk gcc-multilib g++-multilib \
                    gettext git libncurses5-dev libssl-dev python3-distutils rsync unzip zlib1g-dev \
                    file wget libfuse-dev curl

# ==============================================
# 2. 升级Golang工具链到26.x（支持helloworld/Xray编译）
# ==============================================
echo -e "\n===== Step 2: Upgrade Golang to 26.x ====="
rm -rf feeds/packages/lang/golang
git clone --depth=1 https://github.com/sbwml/packages_lang_golang -b 26.x feeds/packages/lang/golang
# 验证Golang版本（编译日志可查）
go version 2>&1 | tee -a ./golang_version.log

# ==============================================
# 3. 添加helloworld源（fw876/helloworld）
# ==============================================
echo -e "\n===== Step 3: Add helloworld feed ====="
echo "src-git helloworld https://github.com/fw876/helloworld.git" >> feeds.conf.default
./scripts/feeds update -a
./scripts/feeds install -a

# ==============================================
# 4. 升级OpenClash到0.4.7版本（删除旧版本+克隆最新源码）
# ==============================================
echo -e "\n===== Step 4: Update OpenClash to 0.4.7 ====="
# 删除系统中旧的OpenClash包（全路径清理，防止版本冲突）
rm -rf feeds/luci/applications/luci-app-openclash
rm -rf package/luci-app-openclash
rm -rf package/feeds/luci/luci-app-openclash
# 克隆OpenClash官方最新源码（0.4.7版本，单分支浅克隆提速）
git clone --depth=1 --single-branch https://github.com/vernesong/OpenClash.git package/luci-app-openclash

# ==============================================
# 5. 配置红米AX6000编译参数 + 修改默认IP为192.168.31.1
# ==============================================
echo -e "\n===== Step 5: Configure Redmi AX6000 & Modify default IP ====="
# 进入编译根目录
cd ./openwrt || exit 1

# 1. 修改默认IP（核心步骤：替换config_generate中的192.168.1.1为192.168.31.1）
sed -i 's/192.168.1.1/192.168.31.1/g' package/base-files/files/bin/config_generate

# 2. 加载红米AX6000默认配置
cp ./configs/mt798x/mt7981-xiaomi-redmi-ax6000.config .config

# 3. 启用OpenClash编译开关 + 集成Meta内核
echo "CONFIG_PACKAGE_luci-app-openclash=y" >> .config
echo "CONFIG_OPENCLASH_USE_META_CORE=y" >> .config  # 强制使用Meta内核（替代旧内核）
echo "CONFIG_OPENCLASH_DOWNLOAD_META_CORE=y" >> .config  # 自动下载最新Meta内核（无需手动编译）

# 4. helloworld组件需手动在make menuconfig中选择（已移除自动勾选逻辑）

# 5. 自定义固件名称（便于识别版本）
sed -i "s/IMG_PREFIX:=immortalwrt/IMG_PREFIX:=ImmortalWrt-RedmiAX6000-$(date +%Y%m%d)-OC047-Meta/" ./include/image.mk

# ==============================================
# 6. 清理编译缓存（防止旧版本残留）
# ==============================================
echo -e "\n===== Step 6: Clean build cache ====="
make clean && make dirclean

echo -e "\n===== DIY part2 completed! ====="
echo "✅ Golang upgraded to 26.x"
echo "✅ helloworld feed added (需手动选择组件)"
echo "✅ OpenClash updated to 0.4.7 (Meta内核已集成)"
echo "✅ Default IP changed to 192.168.31.1"
echo "✅ Redmi AX6000 config loaded"
echo -e "\n⚠️  注意：helloworld组件需执行 make menuconfig 手动勾选后再编译！"
echo "   勾选路径：LuCI → Applications → 选择需要的组件（如luci-app-xray、luci-app-ssr-plus等）"
