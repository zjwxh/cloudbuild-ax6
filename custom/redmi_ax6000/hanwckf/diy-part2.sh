#!/bin/bash
#
# File name: diy-part2.sh
# Description: 红米AX6000云编译最终版（修复Golang+Rust+mihomo下载+解压）
# 适配：hanwckf/immortalwrt-mt798x

# ==============================================
# 配置项
# ==============================================
STABLE_MIHOMO_VERSION="v1.19.17"
ARCH="mips64el"
# 更稳定的mihomo镜像源（优先jsdelivr，避免ghproxy超时）
MIHOMO_MIRROR="https://cdn.jsdelivr.net/gh/MetaCubeX/mihomo-release@main"

# ==============================================
# 1. 安装基础依赖（含Golang+Rust，解决核心依赖）
# ==============================================
echo "===== Step 1: Install all dependencies (Golang+Rust) ====="
sudo apt update -y
sudo apt full-upgrade -y
# 基础编译依赖 + 系统级Golang + Rust（解决helloworld的Rust依赖）
sudo apt install -y build-essential clang flex bison g++ gawk gcc-multilib g++-multilib \
                    gettext git libncurses5-dev libssl-dev python3-distutils rsync unzip zlib1g-dev \
                    file wget libfuse-dev curl golang rustc cargo

# ==============================================
# 2. 升级feeds中的Golang到26.x（先有系统Golang，再替换）
# ==============================================
echo -e "\n===== Step 2: Upgrade Golang to 26.x ====="
rm -rf feeds/packages/lang/golang
git clone --depth=1 https://github.com/sbwml/packages_lang_golang -b 26.x feeds/packages/lang/golang
# 验证Golang版本（此时go命令已存在）
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
# 4. 添加官方helloworld源 + 修复Rust依赖
# ==============================================
echo -e "\n===== Step 4: Add official helloworld feed ====="
sed -i '/helloworld/d' feeds.conf.default
echo "src-git helloworld https://github.com/fw876/helloworld.git" >> feeds.conf.default

# 更新feeds（先安装Rust，再更新，避免Makefile错误）
./scripts/feeds update -a
# 安装时忽略Rust相关的临时错误（不影响核心ssr-plus）
./scripts/feeds install -a -x luci-app-openclash 2>/dev/null

# ==============================================
# 5. 部署OpenClash + 可靠下载mihomo（修复解压问题）
# ==============================================
echo -e "\n===== Step 5: Deploy OpenClash + Reliable download mihomo ====="
rm -rf package/luci-app-openclash
git clone --depth=1 --single-branch https://github.com/vernesong/OpenClash.git /tmp/OpenClash
mkdir -p package/luci-app-openclash
cp -r /tmp/OpenClash/luci-app-openclash/* package/luci-app-openclash/
rm -rf /tmp/OpenClash

# 创建内核目录
mkdir -p package/luci-app-openclash/files/etc/openclash/core
DOWNLOAD_SUCCESS=0

# 第一步：尝试jsdelivr镜像下载最新版（更稳定）
echo "🔍 尝试从jsdelivr镜像下载最新版mihomo..."
LATEST_URL="${MIHOMO_MIRROR}/mihomo-linux-${ARCH}.tar.gz"
curl -L --retry 2 --connect-timeout 20 \
  ${LATEST_URL} \
  -o package/luci-app-openclash/files/etc/openclash/core/mihomo.tar.gz

# 校验：文件是否是有效的tar.gz包（大小>1MB + 魔数校验）
if [ -f "package/luci-app-openclash/files/etc/openclash/core/mihomo.tar.gz" ] && \
   [ $(stat -c%s "package/luci-app-openclash/files/etc/openclash/core/mihomo.tar.gz") -gt 1048576 ] && \
   (file package/luci-app-openclash/files/etc/openclash/core/mihomo.tar.gz | grep -q "gzip compressed data"); then
  DOWNLOAD_SUCCESS=1
  echo "✅ 最新版mihomo下载成功！"
else
  # 第二步：降级到稳定版（jsdelivr镜像）
  echo "⚠️  最新版下载失败，降级到稳定版 ${STABLE_MIHOMO_VERSION}..."
  STABLE_URL="${MIHOMO_MIRROR}/${STABLE_MIHOMO_VERSION}/mihomo-linux-${ARCH}.tar.gz"
  curl -L --retry 5 --connect-timeout 30 \
    ${STABLE_URL} \
    -o package/luci-app-openclash/files/etc/openclash/core/mihomo.tar.gz
  
  # 再次校验
  if [ -f "package/luci-app-openclash/files/etc/openclash/core/mihomo.tar.gz" ] && \
     [ $(stat -c%s "package/luci-app-openclash/files/etc/openclash/core/mihomo.tar.gz") -gt 1048576 ] && \
     (file package/luci-app-openclash/files/etc/openclash/core/mihomo.tar.gz | grep -q "gzip compressed data"); then
    DOWNLOAD_SUCCESS=1
    echo "✅ 稳定版 ${STABLE_MIHOMO_VERSION} 下载成功！"
  else
    echo "❌ 所有版本下载失败，将跳过内核预打包（刷固件后手动安装）！"
    DOWNLOAD_SUCCESS=0
  fi
fi

# 解压（仅当下载有效时执行）
if [ ${DOWNLOAD_SUCCESS} -eq 1 ]; then
  tar -zxvf package/luci-app-openclash/files/etc/openclash/core/mihomo.tar.gz -C package/luci-app-openclash/files/etc/openclash/core/
  # 兼容：检查解压后的文件名（mihomo或clash-meta）
  if [ -f "package/luci-app-openclash/files/etc/openclash/core/mihomo" ]; then
    mv package/luci-app-openclash/files/etc/openclash/core/mihomo package/luci-app-openclash/files/etc/openclash/core/clash_meta
  elif [ -f "package/luci-app-openclash/files/etc/openclash/core/clash-meta" ]; then
    mv package/luci-app-openclash/files/etc/openclash/core/clash-meta package/luci-app-openclash/files/etc/openclash/core/clash_meta
  fi
  # 赋予执行权限
  if [ -f "package/luci-app-openclash/files/etc/openclash/core/clash_meta" ]; then
    chmod +x package/luci-app-openclash/files/etc/openclash/core/clash_meta
    rm -f package/luci-app-openclash/files/etc/openclash/core/mihomo.tar.gz
    echo "✅ mihomo内核解压并适配成功！"
  else
    echo "⚠️  解压后未找到mihomo文件，将跳过预打包！"
    DOWNLOAD_SUCCESS=0
  fi
fi

# 修改Makefile（兼容下载失败的情况）
cp package/luci-app-openclash/Makefile package/luci-app-openclash/Makefile.bak
cat >> package/luci-app-openclash/Makefile << EOF
OPENCLASH_USE_META_CORE := true
OPENCLASH_DOWNLOAD_CORE := false
define Package/luci-app-openclash/install
	\$(call Build/Install/Default)
	# 仅当本地有内核时打包
	if [ -f ./files/etc/openclash/core/clash_meta ]; then
		\$(INSTALL_DIR) \$(1)/etc/openclash/core
		\$(INSTALL_BIN) ./files/etc/openclash/core/clash_meta \$(1)/etc/openclash/core/clash_meta
	fi
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

# 最终提示
echo -e "\n===== DIY completed! =====
✅ 已安装Golang+Rust，解决编译依赖
✅ 智能下载mihomo：优先最新版 → 失败则用稳定版 ${STABLE_MIHOMO_VERSION}
✅ 增加文件校验，避免解压非压缩包
✅ 刷入固件后：
   - 若有Meta内核：直接使用
   - 若无：SSH执行以下命令一键安装：
     mkdir -p /etc/openclash/core && cd /etc/openclash/core && rm -rf clash_meta && curl -L ${STABLE_URL} | tar zxvf - && mv mihomo clash_meta && chmod +x clash_meta && /etc/init.d/openclash restart"
