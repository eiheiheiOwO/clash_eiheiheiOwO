#!/bin/bash

# 颜色设置
GREEN=$(printf '\033[0;32m')
YELLOW=$(printf '\033[0;33m')
RED=$(printf '\033[0;31m')
NC=$(printf '\033[0m')

# 清屏
printf "\033[2J\033[H"

# Logo
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
echo "${YELLOW}                                        Modified for Debian by Gemini                                 ${NC}"


# 1. 检查Root权限
if [ "$(id -u)" -ne 0 ]; then
   echo "${RED}This script must be run as root. Please use sudo.${NC}"
   exit 1
fi

# 2. 检查所有依赖
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
    echo "${RED}Error: The following required packages are missing:${NC}"
    echo "${RED} -> $missing_packages${NC}"
    echo "${YELLOW}Please install them using the following command:${NC}"
    echo "sudo apt-get update && sudo apt-get install -y $missing_packages"
    exit 1
fi

echo "${GREEN}All dependencies are installed.${NC}"

# 3. 自动生成随机 Token 和 Path
generate_random_string() {
    length="$1"
    tr -dc 'A-Za-z0-9' </dev/urandom | head -c "$length"
}

MIAO_TOKEN="$(generate_random_string 32)"
MIAO_PATH="/$(generate_random_string 16)"

if [ -z "$MIAO_TOKEN" ] || [ -z "$MIAO_PATH" ]; then
    echo "${RED}Error: Failed to generate random Token or Path.${NC}"
    exit 1
fi

echo "${GREEN}Configuration generated automatically:${NC}"
echo "${GREEN}Token:     $MIAO_TOKEN${NC}"
echo "${GREEN}Path:      $MIAO_PATH${NC}"
echo "${GREEN}--------------------------------------------------${NC}"


DEFAULT_DIR="/miaoko"
DIR=$DEFAULT_DIR

# 4. 创建安装目录
mkdir -p "$DIR" || {
    echo "${RED}Failed to create directory: $DIR${NC}"
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
        echo "${RED}Unsupported architecture: $arch_raw${NC}"
        exit 1 ;;  
esac
echo "Detected architecture: $arch"

# 函数：从GitHub获取最新发布版URL (不经过代理)
get_latest_url() {
    repo="$1"
    api_url="https://api.github.com/repos/${repo}/releases"

    download_url=$(curl -s "$api_url" \
        | jq -r --arg arch "$arch" '.[0].assets[]
            | select(.name | contains("linux") and contains($arch) and endswith(".tar.gz"))
            | .browser_download_url' \
        | head -n 1)

    if [ -z "$download_url" ] || [ "$download_url" = "null" ]; then
        echo "${RED}Failed to find Linux tar.gz download URL for $repo${NC}"
        exit 1
    fi
    echo "$download_url"
}

# 6. 下载并解压组件 (仅下载 Miaospeed)
repo="AirportR/miaospeed"
echo "Processing $repo..."
url=$(get_latest_url "$repo")
filename="$(basename "$url")"
archive_path="$DIR/$filename"

echo "Downloading from: $url"
curl -sL -o "$archive_path" "${url}"
echo "$repo downloaded to $archive_path."

echo "Extracting $archive_path..."
tar zxf "$archive_path" -C "$DIR" >/dev/null 2>&1 || {
    echo "${RED}Extraction failed for $archive_path${NC}"
    exit 1
}
rm -f "$archive_path"


# 7. 清理不必要的文件
echo "Cleaning up, retaining only 'miaospeed*' in $DIR..."
cd "$DIR" || exit 1
for item in *; do
    case "$item" in
        miaospeed*)
            ;;  
        *)
            rm -rf "$item"
            ;;  
esac
done
chmod +x "$DIR"/miaospeed-linux-"$arch"


# 8. 创建Supervisor配置文件
echo "Creating supervisor configuration for miaospeed..."
cat <<EOF > /etc/supervisor/conf.d/miaospeed.conf
[program:miaospeed]
command=$DIR/miaospeed-linux-$arch server -bind 0.0.0.0:45500 -mtls -token $MIAO_TOKEN -path $MIAO_PATH -ipv6
directory=$DIR
autostart=true
autorestart=true
user=root
stdout_logfile=/var/log/supervisor/miaospeed.log
stderr_logfile=/var/log/supervisor/miaospeed_err.log
EOF

# 9. 重新加载Supervisor并启动服务
echo "Reloading supervisor and starting services..."
supervisorctl reread
supervisorctl update

PUBLIC_IPV4="$(curl -s --max-time 8 ipv4.ip.sb | tr -d '\n')"
if [ -z "$PUBLIC_IPV4" ]; then
    PUBLIC_IPV4="Unavailable"
fi

echo "${GREEN}Installation complete!${NC}"
echo "${GREEN}Miaospeed is now managed by supervisor.${NC}"
echo "${GREEN}Public IPv4: $PUBLIC_IPV4${NC}"
echo "${GREEN}Token:       $MIAO_TOKEN${NC}"
echo "${GREEN}Path:        $MIAO_PATH${NC}"
echo "${GREEN}You can check its status with: supervisorctl status${NC}"
