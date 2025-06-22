#!/bin/bash
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'
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
echo -e "${YELLOW}                                        Shell by TechSky&e1he1he10w0                               ${NC}"
proxy_prefix="https://gh.685763.xyz/"
FILE="/miaoko/frpc"
DIR="/miaokocache"
# 检查文件是否存在，不存在就退出
[ -f "$FILE" ] || {
    echo "文件不存在，脚本退出。"
    exit 1
}
echo "File exists, continuing operation..."
PID=$(ps | grep '[s]upervisord' | awk '{print $1}')
kill -9 $PID
mkdir -p "$DIR" || {
    echo "Failed to create directory: $DIR"
    exit 1
}


arch_raw="$(uname -m)"
case "$arch_raw" in
    x86_64|amd64)
        arch="amd64" ;;  
    aarch64|arm64)
        arch="aarch64" ;;  
    *)
        echo "Unsupported architecture: $arch_raw"
        exit 1 ;;  
esac
echo "Detected architecture: $arch"
rm -f /miaoko/miaospeed-linux-$arch
rm -f /miaoko/frpc
get_latest_url() {
    repo="$1"
    api_url="${proxy_prefix}https://api.github.com/repos/${repo}/releases/latest"

    download_url=$(curl -s "$api_url" \
        | jq -r --arg arch "$arch" '.assets[]
            | select(.name | contains("linux") and contains($arch) and endswith(".tar.gz"))
            | .browser_download_url' \
        | head -n 1)

    if [ -z "$download_url" ] || [ "$download_url" = "null" ]; then
        echo "Failed to find Linux tar.gz download URL for $repo"
        exit 1
    fi
    echo "$download_url"
}
repos="AirportR/miaospeed fatedier/frp"
for repo in $repos; do
    echo "Processing $repo..."
    url=$(get_latest_url "$repo")
    filename="$(basename "$url")"
    archive_path="$DIR/$filename"

    echo "Downloading from: $url"
    curl -sL -o "$archive_path" "${proxy_prefix}${url}"
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
echo "Cleaning up, retaining only 'miaospeed*' and 'frpc' in $DIR..."

cp $DIR/miaospeed-linux-$arch /miaoko/miaospeed-linux-$arch
cp $DIR/frpc /miaoko/frpc
rm -r $DIR
service supervisord start
