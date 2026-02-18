#!/bin/bash

# 颜色设置
GREEN=$(printf '\033[0;32m')
YELLOW=$(printf '\033[0;33m')
RED=$(printf '\033[0;31m')
NC=$(printf '\033[0m')

# 参数
TEST_URL_ONLY=0
REPO="AirportR/miaospeed"

if [ "$1" = "--test-url" ]; then
    TEST_URL_ONLY=1
    if [ -n "$2" ]; then
        REPO="$2"
    fi
elif [ -n "$1" ]; then
    echo "Usage: $0 [--test-url [owner/repo]]"
    exit 1
fi

# GitHub 代理前缀（用于无法直连 GitHub 的区域）
GITHUB_PROXY_PREFIX="https://gh.haitunt.org/"

generate_random_string() {
    length="$1"
    tr -dc 'A-Za-z0-9' </dev/urandom | head -c "$length"
}

with_github_proxy() {
    printf '%s%s' "$GITHUB_PROXY_PREFIX" "$1"
}

detect_arch() {
    arch_raw="$(uname -m)"
    case "$arch_raw" in
        x86_64|amd64)
            printf 'amd64'
            ;;
        aarch64|arm64)
            printf 'arm64'
            ;;
        *)
            echo "${RED}Unsupported architecture: $arch_raw${NC}" >&2
            return 1
            ;;
    esac
}

extract_download_url_from_releases_json() {
    json_content="$1"
    printf '%s' "$json_content" \
        | jq -r --arg arch "$arch" '[.[0].assets[]?
            | select(.name | contains("linux") and contains($arch) and endswith(".tar.gz"))
            | .browser_download_url][0] // empty' 2>/dev/null
}

# 函数：从GitHub获取最新发布版URL (通过代理)
get_latest_url() {
    repo="$1"
    api_url="https://api.github.com/repos/${repo}/releases"
    proxied_api_url="$(with_github_proxy "$api_url")"

    # 先尝试代理 API，再回退直连 API
    for candidate_url in "$proxied_api_url" "$api_url"; do
        api_response="$(curl -fsSL "$candidate_url" 2>/dev/null)" || continue
        download_url="$(extract_download_url_from_releases_json "$api_response")" || continue
        if [ -n "$download_url" ]; then
            echo "$download_url"
            return 0
        fi
    done

    echo "${RED}Failed to find Linux tar.gz download URL for $repo${NC}" >&2
    return 1
}

if ! arch="$(detect_arch)"; then
    exit 1
fi

if [ "$TEST_URL_ONLY" -eq 1 ]; then
    for pkg in curl jq; do
        if ! command -v "$pkg" >/dev/null 2>&1; then
            echo "${RED}Missing dependency: $pkg${NC}" >&2
            exit 1
        fi
    done

    if ! url="$(get_latest_url "$REPO")"; then
        exit 1
    fi

    echo "$url"
    exit 0
fi

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
echo "Detected architecture: $arch"

# 6. 下载并解压组件 (仅下载 Miaospeed)
repo="$REPO"
echo "Processing $repo..."
if ! url="$(get_latest_url "$repo")"; then
    exit 1
fi
filename="$(basename "$url")"
archive_path="$DIR/$filename"

echo "Downloading from: $url"
if ! curl -fsSL -o "$archive_path" "$(with_github_proxy "$url")"; then
    echo "${YELLOW}Proxy download failed, retrying direct URL...${NC}"
    curl -fsSL -o "$archive_path" "$url" || {
        echo "${RED}Download failed for $url${NC}"
        exit 1
    }
fi
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
