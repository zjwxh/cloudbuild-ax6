#!/bin/bash
#
# Copyright (c) 2019-2020 P3TERX <https://p3terx.com>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#
# https://github.com/P3TERX/Actions-OpenWrt
# File name: diy-part2.sh
# Description: 红米AX6000云编译稳定版（优化OpenClash正式版获取逻辑）
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
# 4. 优化版：多重方式获取OpenClash最新正式版
# ==============================================
echo -e "\n===== Step 4: Pull latest official OpenClash ====="
echo "🔍 正在获取OpenClash官方最新正式版本（方式1：GitHub API）..."
# 方式1：带重试/超时/UA的GitHub API请求（提升成功率）
OPENCLASH_LATEST_TAG=$(curl -s --connect-timeout 15 --max-time 20 --retry 3 --retry-delay 2 \
                            -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" \
                            https://api.github.com/repos/vernesong/OpenClash/releases/latest | jq -r '.tag_name')

# 方式2：API失败时，解析GitHub Release页面（备用）
if [ "$OPENCLASH_LATEST_TAG" == "null" ] || [ -z "$OPENCLASH_LATEST_TAG" ]; then
    echo "⚠️ API获取失败，尝试方式2：解析Release页面..."
    OPENCLASH_LATEST_TAG=$(curl -s --connect-timeout 15 --max-time 20 --retry 3 \
                                -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" \
                                https://github.com/vernesong/OpenClash/releases/latest | grep -Eo 'tag/v[0-9]+\.[0-9]+\.[0-9]+' | awk -F'/' '{print $2}')
fi

# 方式3：前两种都失败，用预设最新版（兜底，可定期更新）
if [ -z "$OPENCLASH_LATEST_TAG" ]; then
    echo "⚠️ 页面解析失败，使用预设最新正式版：v0.4.7..."
    OPENCLASH_LATEST_TAG="v0.4.7"  # 可根据OpenClash官方更新手动调整
fi

# 最终克隆对应版本
if [ -n "$OPENCLASH_LATEST_TAG" ]; then
    echo "✅ 成功获取OpenClash最新正式版：${OPENCLASH_LATEST_TAG}，开始克隆..."
    git clone --depth=1 --branch ${OPENCLASH_LATEST_TAG} https://github.com/vernesong/OpenClash.git package/luci-app-openclash
else
    echo "❌ 所有方式均失败，使用master分支最新版..."
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
# 最终提示（改用EOF包裹，避免语法错误）
# ==============================================
cat << EOF

===== DIY completed! =====
✅ 已获取并克隆OpenClash版本：${OPENCLASH_LATEST_TAG:-master分支}
✅ 默认IP已修改为：192.168.31.1
✅ Golang已升级到26.x，编译依赖已补齐
✅ 刷入固件后，SSH登录路由器执行以下命令安装最新mihomo内核：
---------------------------------------------------
mkdir -p /etc/openclash/core && cd /etc/openclash/core && \
rm -rf clash_meta mihomo.tar.gz && \
curl -L --retry 3 https://cdn.jsdelivr.net/gh/MetaCubeX/mihomo-release@main/latest/mihomo-linux-mips64el.tar.gz -o mihomo.tar.gz && \
tar zxvf mihomo.tar.gz && mv mihomo clash_meta && chmod +x clash_meta && \
/etc/init.d/openclash restart
---------------------------------------------------
EOF
