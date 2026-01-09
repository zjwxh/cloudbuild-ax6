#!/bin/bash
#
# File name: diy-part2.sh
# Description: 红米AX6000云编译脚本（自动追新mihomo+稳定版兜底）
# 适配：hanwckf/immortalwrt-mt798x
# 核心逻辑：优先下载最新版mihomo → 失败则自动用验证过的稳定版

# ==============================================
# 配置项（可自行调整稳定版基准）
# ==============================================
# 兜底的稳定版本（已验证mips64el包存在）
STABLE_MIHOMO_VERSION="v1.19.17"
# 架构（红米AX6000固定为mips64el）
ARCH="mips64el"

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
# 3. 清理kenzok8冲突包
# ==============================================
echo -e "\n===== Step 3: Clean conflict packages in kenzok8 feed ====="
rm -rf feeds/kenzok8/luci-app-openclash
rm -rf feeds/kenzok8/luci-app-ssr-plus
rm -rf feeds/kenzok8/xray-core
rm -rf package/feeds/kenzok8/luci-app-openclash
rm -rf package/feeds/kenzok8/luci-app-ssr-plus
sed -i '/luci-app-openclash/d' feeds.conf.default
sed -i '/ssr-plus/d' feeds.conf.default

# ==============================================
# 4. 添加官方helloworld源
# ==============================================
echo -e "\n===== Step 4: Add official helloworld feed ====="
sed -i '/helloworld/d' feeds.conf.default
echo "src-git helloworld https://github.com/fw876/helloworld.git" >> feeds.conf.default
./scripts/feeds update -a
./scripts/feeds install -a -x luci-app-openclash

# ==============================================
# 5. 部署OpenClash + 智能下载mihomo（优先最新版+稳定版兜底）
# ==============================================
echo -e "\n===== Step 5: Deploy OpenClash + Smart download mihomo ====="
rm -rf package/luci-app-openclash
git clone --depth=1 --single-branch https://github.com/vernesong/OpenClash.git /tmp/OpenClash
mkdir -p package/luci-app-openclash
cp -r /tmp/OpenClash/luci-app-openclash/* package/luci-app-openclash/
rm -rf /tmp/OpenClash

# 创建内核目录
mkdir -p package/luci-app-openclash/files/etc/openclash/core
DOWNLOAD_SUCCESS=0

# 第一步：尝试下载最新版mihomo（优先最新）
echo "🔍 尝试下载最新版mihomo..."
LATEST_URL="https://ghproxy.com/https://github.com/MetaCubeX/mihomo/releases/latest/download/mihomo-linux-${ARCH}.tar.gz"
curl -L --retry 2 --connect-timeout 20 \
  ${LATEST_URL} \
  -o package/luci-app-openclash/files/etc/openclash/core/mihomo.tar.gz

# 检查最新版是否下载成功
if [ -f "package/luci-app-openclash/files/etc/openclash/core/mihomo.tar.gz" ] && [ -s "package/luci-app-openclash/files/etc/openclash/core/mihomo.tar.gz" ]; then
  DOWNLOAD_SUCCESS=1
  echo "✅ 最新版mihomo下载成功！"
else
  # 第二步：降级到稳定版（兜底）
  echo "⚠️  最新版下载失败，降级到稳定版 ${STABLE_MIHOMO_VERSION}..."
  STABLE_URL="https://ghproxy.com/https://github.com/MetaCubeX/mihomo/releases/download/${STABLE_MIHOMO_VERSION}/mihomo-linux-${ARCH}.tar.gz"
  curl -L --retry 5 --connect-timeout 30 \
    ${STABLE_URL} \
    -o package/luci-app-openclash/files/etc/openclash/core/mihomo.tar.gz
  
  if [ -f "package/luci-app-openclash/files/etc/openclash/core/mihomo.tar.gz" ] && [ -s "package/luci-app-openclash/files/etc/openclash/core/mihomo.tar.gz" ]; then
    DOWNLOAD_SUCCESS=1
    echo "✅ 稳定版 ${STABLE_MIHOMO_VERSION} 下载成功！"
  else
    echo "❌ 所有版本下载失败，请检查网络或更换镜像站！"
    exit 1
  fi
fi

# 解压并适配OpenClash命名（统一为clash_meta）
if [ ${DOWNLOAD_SUCCESS} -eq 1 ]; then
  tar -zxvf package/luci-app-openclash/files/etc/openclash/core/mihomo.tar.gz -C package/luci-app-openclash/files/etc/openclash/core/
  mv package/luci-app-openclash/files/etc/openclash/core/mihomo package/luci-app-openclash/files/etc/openclash/core/clash_meta
  chmod +x package/luci-app-openclash/files/etc/openclash/core/clash_meta
  rm -f package/luci-app-openclash/files/etc/openclash/core/mihomo.tar.gz
fi

# 修改Makefile打包内核
cp package/luci-app-openclash/Makefile package/luci-app-openclash/Makefile.bak
cat >> package/luci-app-openclash/Makefile << EOF
OPENCLASH_USE_META_CORE := true
OPENCLASH_DOWNLOAD_CORE := false
define Package/luci-app-openclash/install
	\$(call Build/Install/Default)
	\$(INSTALL_DIR) \$(1)/etc/openclash/core
	\$(INSTALL_BIN) ./files/etc/openclash/core/clash_meta \$(1)/etc/openclash/core/clash_meta
endef
EOF

# ==============================================
# 6. 基础配置
# ==============================================
echo -e "\n===== Step 6: Basic config ====="
sed -i 's/192.168.1.1/192.168.31.1/g' package/base-files/files/bin/config_generate
echo "CONFIG_PACKAGE_luci-app-openclash=y" >> .config
sed -i "s/IMG_PREFIX:=immortalwrt/IMG_PREFIX:=ImmortalWrt-RedmiAX6000-$(date +%Y%m%d)-mihomo-auto/" ./include/image.mk

# ==============================================
# 7. 清理缓存
# ==============================================
echo -e "\n===== Step 7: Clean build cache ====="
make clean && make dirclean

echo -e "\n===== DIY completed! =====
✅ 智能下载mihomo：优先最新版 → 失败则用稳定版 ${STABLE_MIHOMO_VERSION}
✅ 内核已预下载并打包进固件
✅ 刷入后OpenClash直接识别mihomo内核！
💡 后续只需修改 STABLE_MIHOMO_VERSION 即可更新兜底版本"
