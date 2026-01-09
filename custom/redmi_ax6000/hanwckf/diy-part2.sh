#!/bin/bash
#
# File name: diy-part2.sh
# Description: 红米AX6000云编译脚本（保留kenzok8+仅用官方helloworld+Meta内核）
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
# 3. 彻底清理kenzok8源中的OpenClash+helloworld相关包（保留其他插件）
# ==============================================
echo -e "\n===== Step 3: Clean OpenClash+helloworld in kenzok8 feed ====="
# 清理kenzok8下的OpenClash
rm -rf feeds/kenzok8/luci-app-openclash
rm -rf package/feeds/kenzok8/luci-app-openclash

# 清理kenzok8下的helloworld相关包（ssr-plus/xray/trojan等）
rm -rf feeds/kenzok8/luci-app-ssr-plus
rm -rf feeds/kenzok8/xray-core
rm -rf feeds/kenzok8/v2ray-core
rm -rf feeds/kenzok8/trojan
rm -rf feeds/kenzok8/shadowsocks-rust
rm -rf feeds/kenzok8/luci-app-xray
rm -rf feeds/kenzok8/luci-app-trojan
rm -rf package/feeds/kenzok8/luci-app-ssr-plus
rm -rf package/feeds/kenzok8/xray-core
rm -rf package/feeds/kenzok8/v2ray-core

# 禁止feeds更新时拉取kenzok8的OpenClash/helloworld
sed -i '/luci-app-openclash/d' feeds.conf.default
sed -i '/ssr-plus/d' feeds.conf.default
sed -i '/xray/d' feeds.conf.default
sed -i '/v2ray/d' feeds.conf.default
sed -i '/trojan/d' feeds.conf.default

# ==============================================
# 4. 添加官方helloworld源（唯一helloworld源）
# ==============================================
echo -e "\n===== Step 4: Add official helloworld feed ====="
# 先删除feeds中已有的helloworld（避免重复）
sed -i '/helloworld/d' feeds.conf.default
# 添加官方fw876/helloworld源（唯一）
echo "src-git helloworld https://github.com/fw876/helloworld.git" >> feeds.conf.default

# 更新feeds并安装（排除OpenClash，避免kenzok8重新拉取）
./scripts/feeds update -a
./scripts/feeds install -a -x luci-app-openclash

# ==============================================
# 5. 部署官方OpenClash + 强制Meta内核（最高优先级）
# ==============================================
echo -e "\n===== Step 5: Deploy official OpenClash + Force Meta Core ====="
# 全量清理其他OpenClash残留
rm -rf package/luci-app-openclash
rm -rf feeds/luci/applications/luci-app-openclash

# 克隆官方OpenClash到本地package（优先级最高）
git clone --depth=1 --single-branch https://github.com/vernesong/OpenClash.git package/luci-app-openclash

# 重写Makefile，强制打包Meta内核到固件
cat > package/luci-app-openclash/Makefile << EOF
include \$(TOPDIR)/rules.mk

PKG_NAME:=luci-app-openclash
PKG_VERSION:=0.47.0
PKG_RELEASE:=1

PKG_MAINTAINER:=vernesong <https://github.com/vernesong/OpenClash>
PKG_LICENSE:=GPL-3.0-only

include \$(INCLUDE_DIR)/package.mk

define Package/luci-app-openclash
  SECTION:=luci
  CATEGORY:=LuCI
  SUBMENU:=Applications
  TITLE:=LuCI support for OpenClash
  PKGARCH:=all
  DEPENDS:=+bash +coreutils +coreutils-nohup +curl +jsonfilter +jq +openssl-util +perl +perl-http-date +perlbase-encode +perlbase-digest +ipset +iptables +iptables-mod-tproxy +libcap +libcap-bin +ruby +ruby-yaml +ca-certificates
endef

define Package/luci-app-openclash/description
  LuCI support for OpenClash
endef

# 强制启用Meta内核
OPENCLASH_USE_META_CORE := true
OPENCLASH_DOWNLOAD_CORE := true
OPENCLASH_COMPILE_CORE := false
OPENCLASH_ARCH := mips64el

define Build/Prepare
endef

define Build/Configure
endef

define Build/Compile
endef

define Package/luci-app-openclash/install
	\$(INSTALL_DIR) \$(1)/
	cp -r ./root/* \$(1)/
	\$(INSTALL_DIR) \$(1)/etc/openclash/core
	# 下载Meta内核并打包到固件
	curl -L https://github.com/MetaCubeX/Clash.Meta/releases/latest/download/clash-meta-linux-mips64el.tar.gz -o \$(1)/etc/openclash/core/clash-meta.tar.gz
	tar -zxvf \$(1)/etc/openclash/core/clash-meta.tar.gz -C \$(1)/etc/openclash/core/
	mv \$(1)/etc/openclash/core/clash-meta \$(1)/etc/openclash/core/clash_meta
	chmod +x \$(1)/etc/openclash/core/clash_meta
	rm -f \$(1)/etc/openclash/core/clash-meta.tar.gz
endef

\$(eval \$(call BuildPackage,luci-app-openclash))
EOF

# ==============================================
# 6. 配置编译参数 + 修改默认IP
# ==============================================
echo -e "\n===== Step 6: Configure build params & Modify default IP ====="
# 修改默认IP为192.168.31.1
sed -i 's/192.168.1.1/192.168.31.1/g' package/base-files/files/bin/config_generate

# 强制启用OpenClash编译
echo "CONFIG_PACKAGE_luci-app-openclash=y" >> .config

# 自定义固件名称
# sed -i "s/IMG_PREFIX:=immortalwrt/IMG_PREFIX:=ImmortalWrt-RedmiAX6000-$(date +%Y%m%d)-OC-Meta-Helloworld/" ./include/image.mk

# ==============================================
# 7. 清理编译缓存
# ==============================================
echo -e "\n===== Step 7: Clean build cache ====="
make clean && make dirclean

echo -e "\n===== DIY part2 completed! =====
✅ 保留kenzok8源（仅清理OpenClash/helloworld）
✅ 仅添加官方fw876/helloworld源（无冲突）
✅ Golang upgraded to 26.x
✅ OpenClash Meta内核已打包到固件（开箱即用）
✅ Default IP changed to 192.168.31.1
✅ kenzok8其他插件（dae/homeproxy等）正常保留！"
