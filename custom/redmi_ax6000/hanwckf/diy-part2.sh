#!/bin/bash
#
# Copyright (c) 2019-2020 P3TERX <https://p3terx.com>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#
# https://github.com/P3TERX/Actions-OpenWrt
# File name: diy-part2.sh
# Description: 红米AX6000云编译稳定版（自动拉取OpenClash最新正式版）
# 适配：hanwckf/immortalwrt-mt798x

# ==============================================
# 1. 安装基础依赖（含解析GitHub API的jq）
# ==============================================
echo "===== Step 1: Install basic dependencies ====="
sudo apt update -y
sudo apt full-upgrade -y
sudo apt install -y build-essential clang flex bison g++ gawk gcc-multilib g++-multilib \
                    gettext git libncurses5-dev libssl-dev python3-distutils rsync unzip zlib1g-dev \
                    file wget libfuse-dev curl jq

# ==============================================
# 2. 升级feeds中的Golang到26.x（解决编译依赖）
# ==============================================
echo -e "\n===== Step 2: Upgrade Golang to 26.x ====="
rm -rf feeds/packages/lang/golang
git clone --depth=1 https://github.com/sbwml/packages_lang_golang -b 26.x feeds/packages/lang/golang

# ==============================================
# 3. 删除旧的OpenClash包（防止版本冲突）
# ==============================================
echo -e "\n===== Step 3: Remove old OpenClash packages ====="
rm -rf feeds/luci/applications/luci-app-openclash
rm -rf package/luci-app-openclash
rm -rf package/feeds/luci/luci-app-openclash

# ==============================================
# 4. 自动拉取OpenClash官方最新正式版
# ==============================================
echo -e "\n===== Step 4: Pull latest official OpenClash ====="
echo "🔍 正在获取OpenClash官方最新正式版本..."
# 通过GitHub API获取最新Release版本号
OPENCLASH_LATEST_TAG=$(curl -s https://api.github.com/repos/vernesong/OpenClash/releases/latest | jq -r '.tag_name')
if [ "$OPENCLASH_LATEST_TAG" != "null" ]; then
    echo "✅ 检测到最新正式版：${OPENCLASH_LATEST_TAG}，开始克隆..."
    git clone --depth=1 --branch ${OPENCLASH_LATEST_TAG} https://github.com/vernesong/OpenClash.git package/luci-app-openclash
else
    echo "⚠️  获取正式版失败，使用master分支最新版..."
    git clone --depth=1 --single-branch https://github.com/vernesong/OpenClash.git package/luci-app-openclash
fi

# 禁用编译时自动下载内核（避免网络超时）
echo "OPENCLASH_DOWNLOAD_CORE := false" >> package/luci-app-openclash/Makefile

# ==============================================
# 5. 启用OpenClash编译开关
# ==============================================
echo -e "\n===== Step 5: Enable OpenClash compile switch ====="
echo "CONFIG_PACKAGE_luci-app-openclash=y" >> .config

# ==============================================
# 6. 基础配置：修改默认IP为192.168.31.1
# ==============================================
echo -e "\n===== Step 6: Basic config (Modify default IP) ====="
sed -i 's/192.168.1.1/192.168.31.1/g' package/base-files/files/bin/config_generate

# ==============================================
# 7. 清理编译缓存（防止旧版本残留）
# ==============================================
echo -e "\n===== Step 7: Clean build cache ====="
make clean && make dirclean

# ==============================================
# 最终提示
# ==============================================
echo -e "\n===== DIY completed! =====
✅ 已自动拉取OpenClash最新正式版：${OPENCLASH_LATEST_TAG:-master分支}
✅ 默认IP已修改为：192.168.31.1
✅ Golang已升级到26.x，编译依赖已补齐
✅ 刷入固件后，SSH登录路由器执行以下命令安装最新mihomo内核：
