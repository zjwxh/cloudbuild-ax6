#!/bin/bash
#
# File name: diy-part2.sh
# Description: 红米AX6000云编译（OpenClash最新版）
# 适配：hanwckf/immortalwrt-mt798x
# 核心：使用你验证过的命令克隆OpenClash最新版

# ==============================================
# 1. 安装基础依赖（仅保留必须项）
# ==============================================
echo "===== Step 1: Install basic dependencies ====="
sudo apt update -y
sudo apt install -y build-essential clang flex bison g++ gawk gcc-multilib g++-multilib \
                    gettext git libncurses5-dev libssl-dev python3-distutils rsync unzip zlib1g-dev \
                    file wget libfuse-dev curl

# ==============================================
# 2. 升级feeds中的Golang到26.x
# ==============================================
echo -e "\n===== Step 2: Upgrade Golang to 26.x ====="
rm -rf feeds/packages/lang/golang
git clone --depth=1 https://github.com/sbwml/packages_lang_golang -b 26.x feeds/packages/lang/golang

# 3. 修改默认IP为192.168.31.1
# ==============================================
echo -e "\n===== Step 6: Modify default IP ====="
sed -i 's/192.168.1.1/192.168.31.1/g' package/base-files/files/bin/config_generate
