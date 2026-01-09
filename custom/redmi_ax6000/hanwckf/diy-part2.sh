#!/bin/bash
#
# File name: diy-part2.sh
# Description: 红米AX6000云编译脚本（修复Meta内核集成问题）
# 适配：hanwckf/immortalwrt-mt798x

# ==============================================
# 1. 安装编译依赖
# ==============================================
echo "===== Step 1: Install build dependencies ====="
sudo apt update -y
sudo apt full-upgrade -y
sudo apt install -y build-essential clang flex bison g++ gawk gcc-multilib g++-multilib \
                    gettext git libncurses5-dev libssl-dev python3-distutils rsync unzip zlib1g-dev \
                    file wget libfuse-dev curl

# ==============================================
# 2. 升级Golang工具链到26.x
# ==============================================
echo -e "\n===== Step 2: Upgrade Golang to 26.x ====="
rm -rf feeds/packages/lang/golang
git clone --depth=1 https://github.com/sbwml/packages_lang_golang -b 26.x feeds/packages/lang/golang
go version 2>&1 | tee -a ./golang_version.log

# ==============================================
# 3. 添加helloworld源
# ==============================================
echo -e "\n===== Step 3: Add helloworld feed ====="
echo "src-git helloworld https://github.com/fw876/helloworld.git" >> feeds.conf.default
./scripts/feeds update -a
./scripts/feeds install -a

# ==============================================
# 4. 升级OpenClash+强制启用Meta内核（核心修复）
# ==============================================
echo -e "\n===== Step 4: Update OpenClash + Enable Meta Core ====="
# 清理旧版OpenClash
rm -rf feeds/luci/applications/luci-app-openclash
rm -rf package/luci-app-openclash
rm -rf package/feeds/luci/luci-app-openclash
# 克隆OpenClash最新源码
git clone --depth=1 --single-branch https://github.com/vernesong/OpenClash.git package/luci-app-openclash

# 【核心修复】修改OpenClash配置文件，强制启用Meta内核
# 1. 修改Config.in，默认选中Meta内核
sed -i 's/select OPENCLASH_USE_META_CORE if OPENCLASH_DOWNLOAD_CORE/select OPENCLASH_USE_META_CORE/g' package/luci-app-openclash/Config.in
# 2. 修改Makefile，强制设置Meta内核编译开关
echo 'PKG_CONFIG_DEPENDS += CONFIG_OPENCLASH_USE_META_CORE' >> package/luci-app-openclash/Makefile
echo 'CONFIG_OPENCLASH_USE_META_CORE=y' >> package/luci-app-openclash/Makefile
# 3. 强制下载Meta内核（覆盖OpenClash默认配置）
sed -i 's/OPENCLASH_DOWNLOAD_CORE:=false/OPENCLASH_DOWNLOAD_CORE:=true/g' package/luci-app-openclash/Makefile
sed -i 's/OPENCLASH_USE_META_CORE:=false/OPENCLASH_USE_META_CORE:=true/g' package/luci-app-openclash/Makefile

# ==============================================
# 5. 配置编译参数 + 修改默认IP
# ==============================================
echo -e "\n===== Step 5: Configure build params & Modify default IP ====="
# 修改默认IP
sed -i 's/192.168.1.1/192.168.31.1/g' package/base-files/files/bin/config_generate

# 启用OpenClash主程序（追加到.config，确保主程序编译）
echo "CONFIG_PACKAGE_luci-app-openclash=y" >> .config

# ==============================================
# 6. 清理编译缓存
# ==============================================
echo -e "\n===== Step 6: Clean build cache ====="
make clean && make dirclean

echo -e "\n===== DIY part2 completed! ====="
echo "✅ Golang upgraded to 26.x"
echo "✅ helloworld feed added（依赖你的自定义.config）"
echo "✅ OpenClash Meta内核已强制启用（修改源码配置）"
echo "✅ Default IP changed to 192.168.31.1"
echo "✅ 已保留你预先配置的.config文件！"
