
#!/bin/bash
# File name: diy-part1.sh
# Description: OpenWrt DIY script part 1 (Before Update feeds)

# 1. 添加 kenzok8 常用包源
sed -i '$a src-git kenzok8 https://github.com/kenzok8/small-package' feeds.conf.default

# 2. 备份原始 feeds
cp feeds.conf.default feeds.conf.default.bak

# 3. 移除可能冲突的旧 OpenClash 源，强制添加最新版
sed -i '/openclash/d' feeds.conf.default
echo "src-git openclash https://github.com/vernesong/OpenClash.git" >> feeds.conf.default

echo "DIY part1 completed: OpenClash official feed added!"
