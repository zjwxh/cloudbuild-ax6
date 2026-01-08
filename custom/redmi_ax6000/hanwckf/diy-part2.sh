#!/bin/bash
#
# Copyright (c) 2019-2020 P3TERX <https://p3terx.com>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#
# https://github.com/P3TERX/Actions-OpenWrt
# File name: diy-part2.sh
# Description: OpenWrt DIY script part 2 (After Update feeds)
#

# Modify default IP
#sed -i 's/192.168.1.1/192.168.50.5/g' package/base-files/files/bin/config_generate
##-----------------Add alist-----------------
#sudo apt update
#sudo apt install libfuse-dev
#rm -rf feeds/packages/lang/golang
#svn export https://github.com/sbwml/packages_lang_golang/branches/19.x feeds/packages/lang/golang
#git clone https://github.com/sbwml/packages_lang_golang -b 20.x feeds/packages/lang/golang

# DIY part2 script for Redmi AX6000 (hanwckf branch)
# 主要作用：替换OpenClash为最新0.4.7版本、调整编译配置

# 1. 删除系统中旧的OpenClash包（防止版本冲突）
rm -rf feeds/luci/applications/luci-app-openclash
rm -rf package/luci-app-openclash
rm -rf package/feeds/luci/luci-app-openclash

# 2. 克隆OpenClash官方最新源码（确保是0.4.7版本）
git clone --depth=1 --single-branch https://github.com/vernesong/OpenClash.git package/luci-app-openclash

# 3. 编译前调整配置：启用OpenClash（确保.config中包含OpenClash编译选项）
# 方式1：直接向.config添加OpenClash编译开关（推荐）
echo "CONFIG_PACKAGE_luci-app-openclash=y" >> .config
# 方式2：如果需要自定义OpenClash版本，可指定内核（可选）
# echo "CONFIG_OPENCLASH_COMPILE_KERNEL=y" >> .config
# echo "CONFIG_OPENCLASH_DOWNLOAD_CORE=y" >> .config

# 4. 可选：清理编译缓存（防止旧版本残留）
make clean && make dirclean

echo "DIY part2 completed: OpenClash updated to 0.4.7!"
