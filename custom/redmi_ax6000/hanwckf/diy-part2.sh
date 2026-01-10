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

# ==============================================
# 3. 删除旧的OpenClash包（防止冲突）
# ==============================================
echo -e "\n===== Step 3: Remove old OpenClash packages ====="
rm -rf feeds/luci/applications/luci-app-openclash
rm -rf package/luci-app-openclash
rm -rf package/feeds/luci/luci-app-openclash

# ==============================================
# 4. 克隆OpenClash最新版（你验证过的核心命令）
# ==============================================
echo -e "\n===== Step 4: Clone latest OpenClash ====="
git clone --depth=1 --single-branch https://github.com/vernesong/OpenClash.git package/luci-app-openclash

# 确保目录存在后，禁用编译时下载内核（修复Makefile报错）
if [ -d "package/luci-app-openclash" ]; then
    echo "OPENCLASH_DOWNLOAD_CORE := false" >> package/luci-app-openclash/Makefile
    echo "✅ OpenClash最新版克隆成功，已禁用内核自动下载"
else
    echo "❌ OpenClash克隆失败！"
    exit 1
fi

# ==============================================
# 5. 启用OpenClash编译开关
# ==============================================
echo -e "\n===== Step 5: Enable OpenClash compile switch ====="
echo "CONFIG_PACKAGE_luci-app-openclash=y" >> .config

# ==============================================
# 6. 修改默认IP为192.168.31.1
# ==============================================
echo -e "\n===== Step 6: Modify default IP ====="
sed -i 's/192.168.1.1/192.168.31.1/g' package/base-files/files/bin/config_generate

# ==============================================
# 7. 清理编译缓存
# ==============================================
echo -e "\n===== Step 7: Clean build cache ====="
make clean && make dirclean

# ==============================================
# 最终提示
# ==============================================
cat << EOF

===== DIY completed! =====
✅ 已克隆OpenClash master分支最新版（你验证过的版本）
✅ 默认IP已修改为：192.168.31.1
✅ Golang已升级到26.x，编译依赖已补齐
✅ 刷入固件后，SSH登录执行以下命令安装最新mihomo内核：
---------------------------------------------------
mkdir -p /etc/openclash/core && cd /etc/openclash/core && \
rm -rf clash_meta mihomo.tar.gz && \
curl -L --retry 3 https://cdn.jsdelivr.net/gh/MetaCubeX/mihomo-release@main/latest/mihomo-linux-mips64el.tar.gz -o mihomo.tar.gz && \
tar zxvf mihomo.tar.gz && mv mihomo clash_meta && chmod +x clash_meta && \
/etc/init.d/openclash restart
---------------------------------------------------
EOF
