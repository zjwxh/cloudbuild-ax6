#!/bin/bash
#
# File name: diy-part2.sh
# Description: 红米AX6000云编译脚本（修复OpenClash root目录+保留kenzok8+官方helloworld+Meta内核）
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
# 3. 清理kenzok8源中的OpenClash+helloworld（保留其他插件）
# ==============================================
echo -e "\n===== Step 3: Clean OpenClash+helloworld in kenzok8 feed ====="
# 清理kenzok8下的OpenClash
rm -rf feeds/kenzok8/luci-app-openclash
rm -rf package/feeds/kenzok8/luci-app-openclash

# 清理kenzok8下的helloworld相关包
rm -rf feeds/kenzok8/luci-app-ssr-plus
rm -rf feeds/kenzok8/xray-core
rm -rf feeds/kenzok8/v2ray-core
rm -rf feeds/kenzok8/trojan
rm -rf feeds/kenzok8/shadowsocks-rust
rm -rf package/feeds/kenzok8/luci-app-ssr-plus
rm -rf package/feeds/kenzok8/xray-core

# 禁止feeds拉取冲突包
sed -i '/luci-app-openclash/d' feeds.conf.default
sed -i '/ssr-plus/d' feeds.conf.default
sed -i '/xray/d' feeds.conf.default

# ==============================================
# 4. 添加官方helloworld源（唯一）
# ==============================================
echo -e "\n===== Step 4: Add official helloworld feed ====="
sed -i '/helloworld/d' feeds.conf.default
echo "src-git helloworld https://github.com/fw876/helloworld.git" >> feeds.conf.default
./scripts/feeds update -a
./scripts/feeds install -a -x luci-app-openclash

# ==============================================
# 5. 部署OpenClash（修正目录结构+适配root路径）
# ==============================================
echo -e "\n===== Step 5: Deploy OpenClash (fix root dir) ====="
# 清理旧OpenClash
rm -rf package/luci-app-openclash
rm -rf feeds/luci/applications/luci-app-openclash

# 克隆官方OpenClash并修正目录结构（让root目录在正确路径）
git clone --depth=1 --single-branch https://github.com/vernesong/OpenClash.git /tmp/OpenClash
mkdir -p package/luci-app-openclash
# 复制OpenClash的所有文件到package/luci-app-openclash（包含root目录）
cp -r /tmp/OpenClash/luci-app-openclash/* package/luci-app-openclash/
rm -rf /tmp/OpenClash

# ==============================================
# 6. 修改OpenClash Makefile（修复root路径+强制Meta内核）
# ==============================================
# 备份原Makefile（保留官方逻辑，仅追加Meta内核配置）
cp package/luci-app-openclash/Makefile package/luci-app-openclash/Makefile.bak

# 追加Meta内核配置到原Makefile（不替换整个Makefile，避免root路径错误）
cat >> package/luci-app-openclash/Makefile << EOF

# 强制启用Meta内核（核心配置）
OPENCLASH_USE_META_CORE := true
OPENCLASH_DOWNLOAD_CORE := true
OPENCLASH_COMPILE_CORE := false
OPENCLASH_ARCH := mips64el

# 编译时自动下载Meta内核到固件
define Package/luci-app-openclash/install
	\$(call Build/Install/Default)
	\$(INSTALL_DIR) \$(1)/etc/openclash/core
	# 下载适配mips64el的Meta内核
	curl -L --retry 3 https://github.com/MetaCubeX/Clash.Meta/releases/latest/download/clash-meta-linux-mips64el.tar.gz -o \$(1)/etc/openclash/core/clash-meta.tar.gz
	if [ -f "\$(1)/etc/openclash/core/clash-meta.tar.gz" ]; then
		tar -zxvf \$(1)/etc/openclash/core/clash-meta.tar.gz -C \$(1)/etc/openclash/core/
		mv \$(1)/etc/openclash/core/clash-meta \$(1)/etc/openclash/core/clash_meta
		chmod +x \$(1)/etc/openclash/core/clash_meta
		rm -f \$(1)/etc/openclash/core/clash-meta.tar.gz
	fi
endef
EOF

# ==============================================
# 7. 配置编译参数 + 修改默认IP
# ==============================================
echo -e "\n===== Step 6: Configure build params ====="
# 修改默认IP
sed -i 's/192.168.1.1/192.168.31.1/g' package/base-files/files/bin/config_generate

# 强制启用OpenClash
echo "CONFIG_PACKAGE_luci-app-openclash=y" >> .config

# 自定义固件名称
# sed -i "s/IMG_PREFIX:=immortalwrt/IMG_PREFIX:=ImmortalWrt-RedmiAX6000-$(date +%Y%m%d)-OC-Meta/" ./include/image.mk

# ==============================================
# 8. 清理编译缓存
# ==============================================
echo -e "\n===== Step 7: Clean build cache ====="
make clean && make dirclean

echo -e "\n===== DIY part2 completed! =====
✅ 修复OpenClash root目录找不到问题
✅ 保留kenzok8源（仅清理冲突包）
✅ 仅使用官方helloworld源
✅ OpenClash Meta内核强制集成
✅ Default IP changed to 192.168.31.1"
