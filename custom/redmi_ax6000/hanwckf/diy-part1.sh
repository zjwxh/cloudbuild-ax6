#!/bin/bash
#
# Copyright (c) 2019-2020 P3TERX <https://p3terx.com>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#
# https://github.com/P3TERX/Actions-OpenWrt
# File name: diy-part1.sh
# Description: OpenWrt DIY script part 1 (Before Update feeds)
#

# Uncomment a feed source
sed -i 's/^#\(.*helloworld\)/\1/' feeds.conf.default
#sed -i "/helloworld/d" "feeds.conf.default"
#echo "src-git helloworld https://github.com/fw876/helloworld.git" >> "feeds.conf.default"
# Add a feed source
#echo 'src-git helloworld https://github.com/fw876/helloworld' >>feeds.conf.default
#echo 'src-git passwall https://github.com/xiaorouji/openwrt-passwall' >>feeds.conf.default
#echo 'src-git kiddin9 https://github.com/kiddin9/kwrt-packages' >>feeds.conf.default
# sed -i '$a src-git kenzok8 https://github.com/kenzok8/small-package' feeds.conf.default

# DIY part1 script for Redmi AX6000 (hanwckf branch)
# 主要作用：修改feeds源、添加所需插件源

# 1. 备份原始feeds.conf.default（可选，防止出错）
cp feeds.conf.default feeds.conf.default.bak


# 3. 添加OpenClash官方源（保留你原有需求）
sed -i '/openclash/d' feeds.conf.default # 先移除旧的，避免重复
echo "src-git openclash https://github.com/vernesong/OpenClash.git" >> feeds.conf.default

# 4. 添加所需插件的可靠第三方源（替代缺失的官方源）
# 4.1 luci-app-wolplus（网络唤醒增强版）
echo "src-git wolplus https://github.com/animegasan/luci-app-wolplus.git" >> feeds.conf.default

# 4.2 luci-app-pptp-server + luci-app-ipsec-server（替换缺失的官方源）
# 使用Lienol仓库（兼容mt798x架构，维护稳定）
echo "src-git lienol https://github.com/Lienol/openwrt-package.git;main" >> feeds.conf.default

# 5. 清理重复源（确保feeds.conf.default整洁）
sed -i '/^src-git /!d' feeds.conf.default

echo "DIY part1 completed: OpenClash + PPTP/IPSec/WOLPlus feeds added!"
