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
echo -e "${YELLOW}                                        Shell by TechSky & e1he1he10w0                               ${NC}"
echo -e "${GREEN}Auto-Update script for miaospeed & frpc with cron setup.${NC}"

# --- 配置 ---
proxy_prefix="https://gh.685763.xyz/"
ghapi="gh.685763.xyz/https://api.github.com/"
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

# 停止服务
stop_services

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
        exit 1 ;;
esac
echo "检测到架构: $arch"

# 清理旧文件
rm -f "$MIAOKO_DIR/miaospeed-linux-$arch"
rm -f "$MIAOKO_DIR/frpc"

# 获取最新版本URL的函数
get_latest_url() {
    local repo="$1"
    local api_url="https://${ghapi}repos/${repo}/releases/latest"
    local download_url

    download_url=$(curl -s "$api_url" \
        | jq -r --arg arch "$arch" '.assets[]
            | select(.name | contains("linux") and contains($arch) and endswith(".tar.gz"))
            | .browser_download_url' \
        | head -n 1)

    if [ -z "$download_url" ] || [ "$download_url" = "null" ]; then
        echo "错误: 未能找到适用于 $repo 的 Linux tar.gz 下载链接"
        exit 1
    fi
    echo "$download_url"
}

# 循环下载和解压
repos="AirportR/miaospeed fatedier/frp"
for repo in $repos; do
    echo "----------------------------------------"
    echo "正在处理仓库: $repo..."
    url=$(get_latest_url "$repo")
    filename="$(basename "$url")"
    archive_path="$CACHE_DIR/$filename"

    echo "正在从以下链接下载: ${proxy_prefix}${url}"
    curl -sL -o "$archive_path" "${proxy_prefix}${url}"
    if [ $? -ne 0 ]; then
        echo "错误: 下载失败: $filename"
        rm -rf "$CACHE_DIR" # 下载失败时清理
        start_services # 尝试恢复服务
        exit 1
    fi
    echo "$repo 已下载至 $archive_path."

    echo "正在解压 $archive_path..."
    tar zxf "$archive_path" -C "$CACHE_DIR" >/dev/null 2>&1 || {
        echo "错误: 解压失败: $archive_path"
        rm -rf "$CACHE_DIR" # 解压失败时清理
        start_services # 尝试恢复服务
        exit 1
    }
    rm -f "$archive_path"

    # 特殊处理frp解压后的目录
    if [ "$repo" = "fatedier/frp" ]; then
        nested_dir=$(find "$CACHE_DIR" -maxdepth 1 -type d -name "frp*linux*${arch}*" | head -n 1)
        if [ -n "$nested_dir" ] && [ -f "$nested_dir/frpc" ]; then
            mv "$nested_dir/frpc" "$CACHE_DIR/"
            rm -rf "$nested_dir"
            echo "frpc 已被提取并移动。"
        fi
    fi
done

echo "----------------------------------------"
echo "更新文件..."
# 从缓存目录拷贝新文件到目标目录
cp "$CACHE_DIR/miaospeed-linux-$arch" "$MIAOKO_DIR/miaospeed-linux-$arch"
cp "$CACHE_DIR/frpc" "$MIAOKO_DIR/frpc"

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
    crontab -l | grep -v "$SCRIPT_PATH" > /tmp/crontab.tmp || true
    
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
if crontab -l | grep -q "$SCRIPT_PATH"; then
    echo "Cron 任务已存在，无需重复设置。"
else
    setup_cron
fi

# 重启服务
start_services
