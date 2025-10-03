#!/bin/bash
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'
SCRIPT_PATH=$(readlink -f "$0")

# ASCII Art and Welcome Message
echo -e "\033[2J\033[H"
echo -e "${GREEN}"
echo " /\$\$   /\$\$  /\$\$\$\$\$\$  /\$\$\$\$\$\$ /\$\$\$\$\$\$\$\$ /\$\$   /\$\$ /\$\$   /\$\$  /\$\$\$\$\$\$  /\$\$\$\$\$\$\$  /\$\$\$\$\$\$\$\$ /\$\$\$\$\$\$\$\$ /\$\$\$\$\$\$\$ "
echo "| \$\$  | \$\$ /\$\$__  \$\$|_  \$\$_/|__  \$\$__/| \$\$  | \$\$| \$\$\$ | \$\$ /\$\$__  \$\$| \$\$__  \$\$| \$\$_____/| \$\$_____/| \$\$__  \$\$"
echo "| \$\$  | \$\$| \$\$  \ \$\$  | \$\$     | \$\$   | \$\$  | \$\$| \$\$\$\$| \$\$| \$\$  \__/| \$\$  \ \$\$| \$\$      | \$\$      | \$\$  \ \$\$"
echo "| \$\$\$\$\$\$\$\$| \$\$\$\$\$\$\$\$  | \$\$     | \$\$   | \$\$  | \$\$| \$\$ \$\$ \$\$|  \$\$\$\$\$\$ | \$\$\$\$\$\$\$/| \$\$\$\$\$   | \$\$\$\$\$   | \$\$  | \$\$"
echo "| \$\$__  \$\$| \$\$__  \$\$  | \$\$     | \$\$   | \$\$  | \$\$| \$\$  \$\$\$\$ \____  \$\$| \$\$____/ | \$\$__/   | \$\$__/   | \$\$  | \$\$"
echo "| \$\$  | \$\$| \$\$  | \$\$  | \$\$     | \$\$   | \$\$  | \$\$| \$\$\  \$\$\$ /\$\$  \ \$\$| \$\$      | \$\$      | \$\$      | \$\$  | \$\$"
echo "| \$\$  | \$\$| \$\$  | \$\$ /\$\$\$\$\$\$   | \$\$   |  \$\$\$\$\$\$/| \$\$ \  \$\$|  \$\$\$\$\$\$/| \$\$      | \$\$\$\$\$\$\$\$| \$\$\$\$\$\$\$\$| \$\$\$\$\$\$\$/"
echo "|__/  |__/|__/  |__/|______/   |__/    \______/ |__/  \__/ \______/ |__/      |________/|________/|_______/ "
echo -e "${NC}"
echo -e "${YELLOW}                                        Shell by TechSky & e1he1he10w0 (Patched)                     ${NC}"
echo -e "${GREEN}Auto-Update script for miaospeed & frpc with cron setup.${NC}"

# --- 配置 ---
proxy_prefix="https://gh.685763.xyz/"
ghapi="gh.685763.xyz/api.github.com" # Removed protocol for clarity
MIAOKO_DIR="/miaoko"
FRPC_FILE="$MIAOKO_DIR/frpc"
MIAOSPEED_FILE_PATTERN="$MIAOKO_DIR/miaospeed-linux-"
CACHE_DIR="/miaokocache"

# --- 服务管理 ---
stop_services() {
    echo "Stopping services..."
    # 检查 supervisord 是否在运行
    if ps | grep -v grep | grep -q 'supervisord'; then
        echo "Detected supervisord running. Stopping it..."
        PID=$(ps | grep '[s]upervisord' | awk '{print $1}')
        if [ -n "$PID" ]; then
            kill -9 "$PID"
            echo "Supervisord stopped."
        fi
        SERVICE_MANAGER="supervisord"
    # 检查 OpenWrt init.d 服务
    elif [ -f /etc/init.d/miaospeed ] && [ -f /etc/init.d/frpc ]; then
        echo "Detected OpenWrt services. Stopping them..."
        /etc/init.d/miaospeed stop
        /etc/init.d/frpc stop
        echo "OpenWrt services stopped."
        SERVICE_MANAGER="openwrt"
    else
        echo "Warning: Could not detect a known service manager (supervisord or OpenWrt services)."
        SERVICE_MANAGER="unknown"
    fi
}

start_services() {
    echo "Starting services..."
    case "$SERVICE_MANAGER" in
        supervisord)
            echo "Starting supervisord..."
            service supervisord start
            ;;
        openwrt)
            echo "Starting OpenWrt services..."
            /etc/init.d/miaospeed start
            /etc/init.d/frpc start
            ;;
        *)
            echo "Warning: Unknown service manager. Please start services manually."
            ;;
    esac
}

# --- 主逻辑 ---
# 检查关键文件是否存在
[ -f "$FRPC_FILE" ] || {
    echo "错误: frpc 文件 ($FRPC_FILE) 不存在，脚本退出。"
    exit 1
}
echo "关键文件存在，继续操作..."

# 创建临时缓存目录
mkdir -p "$CACHE_DIR" || {
    echo "错误: 创建缓存目录失败: $CACHE_DIR"
    exit 1
}

# 检测架构
arch_raw="$(uname -m)"
case "$arch_raw" in
    x86_64|amd64) arch="amd64" ;;
    aarch64|arm64) arch="arm64" ;;
    *)
        echo "错误: 不支持的架构: $arch_raw"
        rm -rf "$CACHE_DIR"
        exit 1 ;;
esac
echo "检测到架构: $arch"

# --- 下载和处理 miaospeed ---
echo "----------------------------------------"
echo "正在处理仓库: AirportR/miaospeed..."
MIAO_API_URL="https://${ghapi}/repos/AirportR/miaospeed/releases/latest"
MIAO_FILENAME="miaospeed-linux-${arch}"
MIAO_URL=$(curl -s "$MIAO_API_URL" | jq -r --arg name "$MIAO_FILENAME" '.assets[] | select(.name == $name) | .browser_download_url' | head -n 1)

if [ -z "$MIAO_URL" ] || [ "$MIAO_URL" = "null" ]; then
    echo "错误: 未能找到适用于 miaospeed 的下载链接 (需要文件: ${MIAO_FILENAME})。"
    rm -rf "$CACHE_DIR"
    exit 1
fi

echo "正在从以下链接下载: ${MIAO_URL}"
curl -sL -o "$CACHE_DIR/$MIAO_FILENAME" "${proxy_prefix}${MIAO_URL}"
if [ $? -ne 0 ]; then
    echo "错误: 下载失败: $MIAO_FILENAME"
    rm -rf "$CACHE_DIR"
    exit 1
fi
echo "miaospeed 已下载至 $CACHE_DIR/$MIAO_FILENAME."

# --- 下载和处理 frp ---
echo "----------------------------------------"
echo "正在处理仓库: fatedier/frp..."
FRP_API_URL="https://${ghapi}/repos/fatedier/frp/releases/latest"
FRP_URL=$(curl -s "$FRP_API_URL" | jq -r --arg arch "$arch" '.assets[] | select(.name | contains("linux") and contains($arch) and endswith(".tar.gz")) | .browser_download_url' | head -n 1)

if [ -z "$FRP_URL" ] || [ "$FRP_URL" = "null" ]; then
    echo "错误: 未能找到适用于 frp 的 Linux tar.gz 下载链接。"
    rm -rf "$CACHE_DIR"
    exit 1
fi

FRP_FILENAME=$(basename "$FRP_URL")
ARCHIVE_PATH="$CACHE_DIR/$FRP_FILENAME"
echo "正在从以下链接下载: ${FRP_URL}"
curl -sL -o "$ARCHIVE_PATH" "${proxy_prefix}${FRP_URL}"
if [ $? -ne 0 ]; then
    echo "错误: 下载失败: $FRP_FILENAME"
    rm -rf "$CACHE_DIR"
    exit 1
fi
echo "frp 已下载至 $ARCHIVE_PATH."

echo "正在解压 $ARCHIVE_PATH..."
tar zxf "$ARCHIVE_PATH" -C "$CACHE_DIR" >/dev/null 2>&1 || {
    echo "错误: 解压失败: $ARCHIVE_PATH"
    rm -rf "$CACHE_DIR"
    exit 1
}
rm -f "$ARCHIVE_PATH"

# 提取frpc
nested_dir=$(find "$CACHE_DIR" -maxdepth 1 -type d -name "frp*linux*${arch}*" | head -n 1)
if [ -n "$nested_dir" ] && [ -f "$nested_dir/frpc" ]; then
    mv "$nested_dir/frpc" "$CACHE_DIR/"
    rm -rf "$nested_dir"
    echo "frpc 已被提取并移动。"
fi

echo "----------------------------------------"
# --- 下载后验证文件 ---
echo "正在验证下载的文件..."
MIAOSPEED_NEW_FILE="$CACHE_DIR/miaospeed-linux-$arch"
FRPC_NEW_FILE="$CACHE_DIR/frpc"

if [ ! -s "$MIAOSPEED_NEW_FILE" ]; then
    echo "错误: 下载的 miaospeed 文件 ($MIAOSPEED_NEW_FILE) 无效或为空。正在中止更新。"
    rm -rf "$CACHE_DIR"
    exit 1
fi

if [ ! -s "$FRPC_NEW_FILE" ]; then
    echo "错误: 下载的 frpc 文件 ($FRPC_NEW_FILE) 无效或为空。正在中止更新。"
    rm -rf "$CACHE_DIR"
    exit 1
fi
echo "文件验证成功！准备应用更新。"
# --- 验证结束 ---


# 停止服务
stop_services

# 清理旧文件
echo "正在清理旧版本..."
rm -f "$MIAOKO_DIR/miaospeed-linux-$arch"
rm -f "$MIAOKO_DIR/frpc"

echo "正在更新文件..."
# 从缓存目录拷贝新文件到目标目录
cp "$MIAOSPEED_NEW_FILE" "$MIAOKO_DIR/miaospeed-linux-$arch"
cp "$FRPC_NEW_FILE" "$MIAOKO_DIR/frpc"

# 赋予执行权限
chmod +x "$MIAOKO_DIR/miaospeed-linux-$arch"
chmod +x "$MIAOKO_DIR/frpc"

echo "清理临时文件..."
rm -r "$CACHE_DIR"

echo "更新完成！"

# --- Cron 任务设置 ---
setup_cron() {
    echo "正在设置每日自动更新的 cron 任务..."
    # 随机生成分钟数 (0-59)
    RANDOM_MINUTE=$(( RANDOM % 60 ))
    # 固定小时为4点
    CRON_HOUR=4
    CRON_CMD="$RANDOM_MINUTE $CRON_HOUR * * * $SCRIPT_PATH"
    
    # 检查 crontab 中是否已有此脚本的任务
    (crontab -l 2>/dev/null | grep -v "$SCRIPT_PATH") > /tmp/crontab.tmp
    
    echo "将添加以下 cron 任务:"
    echo "$CRON_CMD"
    
    # 添加新的任务
    echo "$CRON_CMD" >> /tmp/crontab.tmp
    
    # 应用新的 crontab
    crontab /tmp/crontab.tmp
    rm /tmp/crontab.tmp
    
    echo "Cron 任务设置成功！脚本将在每天 ${CRON_HOUR}:${RANDOM_MINUTE} 自动运行。"
}

# 检查是否需要设置cron
if crontab -l 2>/dev/null | grep -q "$SCRIPT_PATH"; then
    echo "Cron 任务已存在，无需重复设置。"
else
    setup_cron
fi

# 重启服务
start_services
