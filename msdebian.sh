#!/bin/bash

# 通过 $(printf '\...') 的方式直接将颜色代码赋值给变量
# 这样后续的 echo 命令就不再需要 -e 参数，拥有最好的兼容性
GREEN=$(printf '\033[0;32m')
YELLOW=$(printf '\033[0;33m')
NC=$(printf '\033[0m')

# 清屏
printf "\033[2J\033[H"

# 使用 echo 和已经解析好的颜色变量来显示LOGO
echo "${GREEN}"
echo ' /$$   /$$  /$$$$$$  /$$$$$$ /$$$$$$$$ /$$   /$$ /$$   /$$  /$$$$$$  /$$$$$$$  /$$$$$$$$ /$$$$$$$$ /$$$$$$$'
echo '| $$  | $$ /$$__  $$|_  $$_/|__  $$__/| $$  | $$| $$$ | $$ /$$__  $$| $$__  $$| $$_____/| $$_____/| $$__  $$'
echo '| $$  | $$| $$  \ $$  | $$     | $$   | $$  | $$| $$$$| $$| $$  \__/| $$  \ $$| $$      | $$      | $$  \ $$'
echo '| $$$$$$$$| $$$$$$$$  | $$     | $$   | $$  | $$| $$ $$ $$|  $$$$$$ | $$$$$$$/| $$$$$   | $$$$$   | $$  | $$'
echo '| $$__  $$| $$__  $$  | $$     | $$   | $$  | $$| $$  $$$$ \____  $$| $$____/ | $$__/   | $$__/   | $$  | $$'
echo '| $$  | $$| $$  | $$  | $$     | $$   | $$  | $$| $$\  $$$ /$$  \ $$| $$      | $$      | $$      | $$  | $$'
echo '| $$  | $$| $$  | $$ /$$$$$$   | $$   |  $$$$$$/| $$ \  $$|  $$$$$$/| $$      | $$$$$$$$| $$$$$$$$| $$$$$$$/'
echo '|__/  |__/|__/  |__/|______/   |__/    \______/ |__/  \__/ \______/ |__/      |________/|________/|_______/ '
echo "${NC}"
echo "${YELLOW}                                        Shell by TechSky & e1he1he10w0                               ${NC}"
echo "${YELLOW}                                        Modified for Debian by Gemini                                    ${NC}"


# 1. 检查Root权限
if [ "$(id -u)" -ne 0 ]; then
   echo "${YELLOW}This script must be run as root. Please use sudo.${NC}"
   exit 1
fi

# 2. 检查所有依赖并统一报告
echo "Checking for required dependencies..."
missing_packages=""

for pkg in curl jq tar; do
    if ! command -v "$pkg" >/dev/null 2>&1; then
        missing_packages="$missing_packages $pkg"
    fi
done

if ! command -v "supervisorctl" >/dev/null 2>&1; then
    missing_packages="$missing_packages supervisor"
fi

if [ -n "$missing_packages" ]; then
    missing_packages="${missing_packages# }"
    echo "${YELLOW}Error: The following required packages are missing:${NC}"
    echo "${YELLOW} -> $missing_packages${NC}"
    echo "${YELLOW}Please install them using the following command:${NC}"
    echo "sudo apt-get update && sudo apt-get install -y $missing_packages"
    exit 1
fi

echo "${GREEN}All dependencies are installed.${NC}"


ghproxy="https://gh.685763.xyz/"
ghapi="https://api.github.com/"

# 函数：获取用户配置
configure_miaospeed() {
    DEFAULT_DIR="/miaoko"
    while true; do
        # 使用 echo -n 和 read 的组合，以获得最佳兼容性
	    echo -n "${YELLOW}Please enter your username:${NC} "
        read -r USER
	    echo -n "${YELLOW}Would you like to customize the installation path?(y/N): ${NC} "
        read -r CUSTOM_DIR
        CUSTOM_DIR=${CUSTOM_DIR:-N}
        
        case "$CUSTOM_DIR" in
            [Yy]*)
                echo -n "${YELLOW}Please enter the installation path (e.g., /miaoko): ${NC} "
                read -r USER_DIR
                DIR=${USER_DIR:-$DEFAULT_DIR}
                ;;
            *)
                DIR=$DEFAULT_DIR
                ;;
        esac

        echo -n "${YELLOW}Please enter the TOKEN: ${NC} "
        read -r TOKEN_PARAM
        echo -n "${YELLOW}Please enter the PATH: ${NC} "
        read -r PATH_PARAM
        echo -n "${YELLOW}Please enter the FRP access port:${NC} "
        read -r FRPPORT_PARAM
        
        echo ""
        echo "${GREEN}--------------------------------------------------${NC}"
        echo "${GREEN}Miaospeed configuration information for user:$USER ${NC}"
        echo "${GREEN}Installation directory:$DIR ${NC}"
        echo "${GREEN}FRP access port:$FRPPORT_PARAM ${NC}"
        echo "${GREEN}Path: $PATH_PARAM${NC}"
        echo "${GREEN}Token: $TOKEN_PARAM${NC}"
        echo "${GREEN}--------------------------------------------------${NC}"
        echo ""
        
        echo -n "${YELLOW}Please confirm whether the above information is correct.(Y/n): ${NC} "
        read -r CONFIRM_CHOICE
        CONFIRM_CHOICE=${CONFIRM_CHOICE:-Y}

        case "$CONFIRM_CHOICE" in
            [Yy]*)
                break
                ;;
            *)
                echo "${YELLOW}Please re-enter the configuration information.${NC}"
                ;;
        esac
    done
}

# --- 主脚本逻辑 ---

# 3. 获取用户配置
configure_miaospeed

# 4. 创建安装目录
mkdir -p "$DIR" || {
    echo "Failed to create directory: $DIR"
    exit 1
}
echo "Downloads will be saved to: $DIR"

# 5. 检测系统架构
arch_raw="$(uname -m)"
case "$arch_raw" in
    x86_64|amd64)
        arch="amd64" ;;  
    aarch64|arm64)
        arch="arm64" ;;  
    *)
        echo "Unsupported architecture: $arch_raw"
        exit 1 ;;  
esac
echo "Detected architecture: $arch"

# 函数：从GitHub获取最新发布版URL
get_latest_url() {
    repo="$1"
    # --- MODIFICATION 1: REMOVED /latest TO GET ALL RELEASES (INCLUDING PRE-RELEASES) ---
    api_url="https://api.github.com/repos/${repo}/releases"

    download_url=$(curl -s "$api_url" \
        | jq -r --arg arch "$arch" '.[0].assets[] # --- MODIFICATION 2: ADDED .[0] TO GET THE FIRST (NEWEST) RELEASE FROM THE LIST ---
            | select(.name | contains("linux") and contains($arch) and endswith(".tar.gz"))
            | .browser_download_url' \
        | head -n 1)

    if [ -z "$download_url" ] || [ "$download_url" = "null" ]; then
        echo "Failed to find Linux tar.gz download URL for $repo"
        exit 1
    fi
    echo "$download_url"
}

# 6. 下载并解压组件
repos="AirportR/miaospeed fatedier/frp"
for repo in $repos; do
    echo "Processing $repo..."
    url=$(get_latest_url "$repo")
    filename="$(basename "$url")"
    archive_path="$DIR/$filename"

    echo "Downloading from: $url"
    curl -sL -o "$archive_path" "${ghproxy}${url}"
    echo "$repo downloaded to $archive_path."

    echo "Extracting $archive_path..."
    tar zxf "$archive_path" -C "$DIR" >/dev/null 2>&1 || {
        echo "Extraction failed for $archive_path"
        exit 1
    }
    rm -f "$archive_path"

    if [ "$repo" = "fatedier/frp" ]; then
        nested_dir=$(find "$DIR" -maxdepth 1 -type d -name "frp*linux*${arch}*" | head -n 1)
        if [ -n "$nested_dir" ]; then
            mv "$nested_dir/frpc" "$DIR/" 2>/dev/null || true
            rm -rf "$nested_dir"
            echo "frpc extracted and moved to $DIR"
        fi
    fi
done

# 7. 清理不必要的文件
echo "Cleaning up, retaining only 'miaospeed*' and 'frpc' in $DIR..."
cd "$DIR" || exit 1
for item in *; do
    case "$item" in
        miaospeed*|frpc)
            ;;  
        *)
            rm -rf "$item"
            ;;  
esac
done
chmod +x "$DIR"/miaospeed-linux-"$arch" "$DIR"/frpc

# 8. 创建frpc配置文件
cat <<EOF > "$DIR/frpc.toml"
serverAddr = "a.haitunt.org"
serverPort = 10102
auth.method = "token"
auth.token = "OUaW6oLUSzNjmSb2"
dnsServer = "223.5.5.5"

[[proxies]]
name = "$USER.$FRPPORT_PARAM"
type = "tcp"
localIP = "127.0.0.1"
localPort = 45500
remotePort = $FRPPORT_PARAM
EOF

# 9. 创建Supervisor配置文件
echo "Creating supervisor configuration for miaospeed..."
cat <<EOF > /etc/supervisor/conf.d/miaospeed.conf
[program:miaospeed]
command=$DIR/miaospeed-linux-$arch server -bind 127.0.0.1:45500 -mtls -token $TOKEN_PARAM -path $PATH_PARAM -ipv6
directory=$DIR
autostart=true
autorestart=true
user=root
stdout_logfile=/var/log/supervisor/miaospeed.log
stderr_logfile=/var/log/supervisor/miaospeed_err.log
EOF

echo "Creating supervisor configuration for frpc..."
cat <<EOF > /etc/supervisor/conf.d/frpc.conf
[program:frpc]
command=$DIR/frpc -c $DIR/frpc.toml
directory=$DIR
autostart=true
autorestart=true
user=root
stdout_logfile=/var/log/supervisor/frpc.log
stderr_logfile=/var/log/supervisor/frpc_err.log
EOF

# 10. 重新加载Supervisor并启动服务
echo "Reloading supervisor and starting services..."
supervisorctl reread
supervisorctl update

echo "${GREEN}Installation complete!${NC}"
echo "${GREEN}Miaospeed and frpc are now managed by supervisor.${NC}"
echo "${GREEN}You can check their status with: supervisorctl status${NC}"
