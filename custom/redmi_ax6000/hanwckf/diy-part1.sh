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
#sed -i 's/^#\(.*helloworld\)/\1/' feeds.conf.default
#sed -i "/helloworld/d" "feeds.conf.default"
#echo "src-git helloworld https://github.com/fw876/helloworld.git" >> "feeds.conf.default"
# Add a feed source
#echo 'src-git helloworld https://github.com/fw876/helloworld' >>feeds.conf.default
#echo 'src-git passwall https://github.com/xiaorouji/openwrt-passwall' >>feeds.conf.default
#echo 'src-git kiddin9 https://github.com/kiddin9/kwrt-packages' >>feeds.conf.default
sed -i '$a src-git kenzok8 https://github.com/kenzok8/small-package' feeds.conf.default
# DIY part1 script for Redmi AX6000 (hanwckf branch)
# 主要作用：修改feeds源、添加OpenClash官方源

# 1. 备份原始feeds.conf.default（可选，防止出错）
cp feeds.conf.default feeds.conf.default.bak

# 2. 添加OpenClash官方源（优先拉取最新0.4.7版本）
echo "src-git openclash https://github.com/vernesong/OpenClash.git" >> feeds.conf.default

# 3. 可选：添加其他常用feeds（如果有需要可取消注释）
# echo "src-git passwall https://github.com/xiaorouji/openwrt-passwall.git" >> feeds.conf.default
# echo "src-git passwall_packages https://github.com/xiaorouji/openwrt-passwall-packages.git" >> feeds.conf.default

# 4. 移除可能冲突的旧OpenClash源（如果有的话）
sed -i '/openclash/d' feeds.conf.default
# 重新添加最新OpenClash源（确保唯一）
echo "src-git openclash https://github.com/vernesong/OpenClash.git" >> feeds.conf.default

echo "DIY part1 completed: OpenClash official feed added!"
