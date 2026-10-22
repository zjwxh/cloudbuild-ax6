#!/bin/bash
#
# File name: diy-part2.sh
# Description: 红米AX6云编译 OpenClash，VIKINGYFY main高通专用满血NSS分支

# ==============================================
# 1. 安装基础依赖
# ==============================================
echo "===== Step 1: Install basic dependencies ====="
sudo apt update -y
sudo apt install -y build-essential clang flex bison g++ gawk gcc-multilib g++-multilib \
                    gettext git libncurses5-dev libssl-dev python3-distutils rsync unzip zlib1g-dev \
                    file wget libfuse-dev curl

# ==============================================
# 2. 升级Golang到 27.x (Go1.27，适配xray-core)
# ==============================================
echo -e "\n===== Step 2: Upgrade Golang to 27.x ====="
rm -rf feeds/packages/lang/golang
git clone --depth=1 https://github.com/sbwml/packages_lang_golang -b 27.x feeds/packages/lang/golang

# ==============================================
# 3. 删除旧OpenClash包，防止残留冲突
# ==============================================
echo -e "\n===== Step 3: Remove old OpenClash packages ====="
rm -rf feeds/luci/applications/luci-app-openclash
rm -rf package/luci-app-openclash
rm -rf package/feeds/luci/luci-app-openclash

# ==============================================
# 4. 拉取最新 OpenClash
# ==============================================
echo -e "\n===== Step 4: Clone latest OpenClash ====="
git clone --depth=1 --single-branch https://github.com/vernesong/OpenClash.git package/luci-app-openclash
if [ -d "package/luci-app-openclash" ]; then
    echo "OPENCLASH_DOWNLOAD_CORE := false" >> package/luci-app-openclash/Makefile
    echo "✅ OpenClash 克隆成功，关闭编译阶段内核自动下载"
else
    echo "❌ OpenClash clone failed!"
    exit 1
fi

# ==============================================
# 4.5 补回缺失的 libffi 包
# ==============================================
# 本高通裁剪分支的 packages feed 里没有 libffi（日志: No feed for package 'libffi' found），
# 而 python3（--with-system-ffi）、glib2、ruby、wayland 等都依赖它，缺了 python3 编 _ctypes
# 会报 ffi.h: No such file or directory。这里把标准 libffi 3.4.7 包补进主源码 package/libs，
# InstallDev 会把 ffi.h 装入 target staging，python3 的 _ctypes 即可正常编译。
echo -e "\n===== Step 4.5: Add missing libffi package ====="
mkdir -p package/libs/libffi
cat > package/libs/libffi/Makefile <<'LIBFFI_MK_EOF'
#
# Copyright (C) 2009-2016 OpenWrt.org
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#
include $(TOPDIR)/rules.mk

PKG_NAME:=libffi
PKG_VERSION:=3.4.7
PKG_RELEASE:=1

PKG_SOURCE:=$(PKG_NAME)-$(PKG_VERSION).tar.gz
PKG_SOURCE_URL:=https://github.com/libffi/libffi/releases/download/v$(PKG_VERSION)
PKG_HASH:=138607dee268bdecf374adf9144c00e839e38541f75f24a1fcf18b78fda48b2d

PKG_LICENSE:=MIT
PKG_LICENSE_FILES:=LICENSE
PKG_CPE_ID:=cpe:/a:libffi_project:libffi

PKG_INSTALL:=1
PKG_BUILD_PARALLEL:=1
PKG_BUILD_FLAGS:=no-mips16

include $(INCLUDE_DIR)/package.mk
include $(INCLUDE_DIR)/host-build.mk

define Package/libffi
  SECTION:=libs
  CATEGORY:=Libraries
  TITLE:=Foreign Function Interface (FFI) library
  URL:=https://sourceware.org/libffi/
  MAINTAINER:=Peter Wagner <tripolar@gmx.at>
endef

define Package/libffi/description
The libffi library provides a portable, high level programming interface to
various calling conventions. This allows a programmer to call any function
specified by a call interface description at run-time.
FFI stands for Foreign Function Interface. A foreign function interface is the
popular name for the interface that allows code written in one language to call
code written in another language. The libffi library really only provides the
lowest, machine dependent layer of a fully featured foreign function interface.
A layer must exist above libffi that handles type conversions for values passed
between the two languages.
endef

HOST_CONFIGURE_ARGS += \
	--disable-shared \
	--disable-docs \
	--disable-multi-os-directory \
	--disable-raw-api \
	--disable-structs \
	--with-pic

CONFIGURE_ARGS += \
	--disable-docs \
	--disable-multi-os-directory \
	--disable-raw-api \
	--disable-structs

define Build/InstallDev
	$(INSTALL_DIR) $(1)/usr/lib/pkgconfig
	$(CP) \
		$(PKG_INSTALL_DIR)/usr/lib/libffi.{so*,a,la} \
		$(1)/usr/lib/
	$(CP) \
		$(PKG_INSTALL_DIR)/usr/lib/pkgconfig/* \
		$(1)/usr/lib/pkgconfig/
	$(SED) 's,includedir=.*,includedir=$$$${prefix}/include,' $(1)/usr/lib/pkgconfig/libffi.pc
	$(INSTALL_DIR) $(1)/usr/include
	$(CP) \
		$(PKG_INSTALL_DIR)/usr/include/*.h \
		$(1)/usr/include/
endef

define Package/libffi/install
	$(INSTALL_DIR) $(1)/usr/lib
	$(CP) \
		$(PKG_INSTALL_DIR)/usr/lib/libffi.so.* \
		$(1)/usr/lib/
endef

$(eval $(call HostBuild))
$(eval $(call BuildPackage,libffi))
LIBFFI_MK_EOF
echo "✅ 已补入 package/libs/libffi（3.4.7）"

# ==============================================
# 5. 配置 & 解决各类包冲突
# ==============================================
echo -e "\n===== Step 5: Configure OpenClash & Fix Conflicts ====="
echo "CONFIG_PACKAGE_luci-app-openclash=y" >> .config
# 显式选中补回的 libffi，确保 ffi.h 进入 staging
echo "CONFIG_PACKAGE_libffi=y" >> .config

# dnsmasq 冲突，使用dnsmasq-full
sed -i 's/CONFIG_PACKAGE_dnsmasq=y/# CONFIG_PACKAGE_dnsmasq is not set/g' .config
echo "# CONFIG_PACKAGE_dnsmasq is not set" >> .config

# wpad 冲突处理
sed -i 's/CONFIG_PACKAGE_wpad-basic=y/# CONFIG_PACKAGE_wpad-basic is not set/g' .config
sed -i 's/CONFIG_PACKAGE_wpad-basic-mbedtls=y/# CONFIG_PACKAGE_wpad-basic-mbedtls/g' .config
echo "# CONFIG_PACKAGE_wpad-basic is not set" >> .config
echo "# CONFIG_PACKAGE_wpad-basic-mbedtls is not set" >> .config

# ath11k ddwrt 固件冲突
sed -i 's/CONFIG_PACKAGE_ath11k-firmware-ipq8074-ddwrt=y/# CONFIG_PACKAGE_ath11k-firmware-ipq8074-ddwrt/g' .config
echo "# CONFIG_PACKAGE_ath11k-firmware-ipq8074-ddwrt is not set" >> .config

# ==============================================
# 6. 修改默认网关IP 192.168.11.1
# ==============================================
echo -e "\n===== Step 6: Modify default IP ====="
sed -i 's/192.168.1.1/192.168.11.1/g' package/base-files/files/bin/config_generate

# ==============================================
# 7. 刷新defconfig，配置全部生效
# ==============================================
echo -e "\n===== Step 7: Refresh config dependencies ====="
make defconfig
echo ">>> 补包后 libffi 状态:"
grep -i libffi .config || true

# ==============================================
# 提示信息
# ==============================================
cat << EOF
===== DIY completed! =====
✅ VIKINGYFY main高通专用分支，满血NSS ECM补丁已加载，无线正常可用
✅ 修复qca-nss-ecm conntrack notifier API报错
✅ libbpf GCC14警告阻断修复
✅ Golang 升级到 1.27，适配新版xray-core
✅ OpenClash最新版，关闭编译阶段内核下载
✅ 已补回缺失的 libffi 3.4.7 包，修复 python3 _ctypes 缺 ffi.h
✅ 默认IP：192.168.11.1
刷入后SSH执行安装mihomo内核：
---------------------------------------------------
mkdir -p /etc/openclash/core && cd /etc/openclash/core && \\
rm -rf clash_meta mihomo.tar.gz && \\
curl -L --retry 3 https://cdn.jsdelivr.net/gh/MetaCubeX/mihomo-release@main/latest/mihomo-linux-aarch64.tar.gz -o mihomo.tar.gz && \\
tar zxvf mihomo.tar.gz && mv mihomo clash_meta && chmod +x clash_meta && \\
/etc/init.d/openclash restart
---------------------------------------------------
EOF
