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
echo -e "${YELLOW}                                        Shell by TechSky & e1he1he10w0                               ${NC}"
ghproxy="https://gh.685763.xyz/"
ghapi="https://api.github.com/"
configure_miaospeed() {
    DEFAULT_DIR="/miaoko"
    while true; do
	    read -rp "$(echo -e "${YELLOW}Please enter your username:${NC}")" USER
	    read -rp "$(echo -e "${YELLOW}Would you like to customize the installation path?(y/N): ${NC}")" CUSTOM_DIR
        CUSTOM_DIR=${CUSTOM_DIR:-N}
        if [[ "$CUSTOM_DIR" =~ ^[Yy]$ ]]; then
            read -rp "$(echo -e "${YELLOW}Please enter the installation path (e.g., /miaoko): ${NC}")" USER_DIR
            DIR=${USER_DIR:-$DEFAULT_DIR}
        else
            DIR=$DEFAULT_DIR
		fi
        read -rp "$(echo -e "${YELLOW}Please enter the TOKEN: ${NC}")" TOKEN_PARAM
        read -rp "$(echo -e "${YELLOW}Please enter the PATH: ${NC}")" PATH_PARAM
        read -rp "$(echo -e "${YELLOW}Please enter the FRP access port:${NC}")" FRPPORT_PARAM
        echo ""
        echo -e "${GREEN}--------------------------------------------------${NC}"
        echo -e "${GREEN}Miaospeed configuration information for user:$USER ${NC}"
        echo -e "${GREEN}Installation directory:$DIR ${NC}"
        echo -e "${GREEN}FRP access port:$FRPPORT_PARAM ${NC}"
        echo -e "${GREEN}Path: $PATH_PARAM${NC}"
        echo -e "${GREEN}Token: $TOKEN_PARAM${NC}"
        echo -e "${GREEN}--------------------------------------------------${NC}"
        echo ""
        read -rp "$(echo -e "${YELLOW}Please confirm whether the above information is correct.(Y/n): ${NC}")" CONFIRM_CHOICE
        CONFIRM_CHOICE=${CONFIRM_CHOICE:-Y}
        if [[ "$CONFIRM_CHOICE" =~ ^[Yy]$ ]]; then
            break
        else
            echo -e "${YELLOW}Please re-enter the configuration information.${NC}"
        fi
    done
}
configure_miaospeed
mkdir -p "$DIR" || {
    echo "Failed to create directory: $DIR"
    exit 1
}
echo "Downloads will be saved to: $DIR"
for cmd in curl jq tar; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Error: $cmd is not installed. Please install it."
    exit 1
  fi
done
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
get_latest_url() {
    repo="$1"
    api_url="https://${ghapi}repos/${repo}/releases/latest"

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
cat <<EOF > $DIR/frpc.toml
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
cat <<EOF > /etc/init.d/miaospeed
#!/bin/sh /etc/rc.common
START=99
STOP=10
USE_PROCD=1
start_service() {
    procd_open_instance
    procd_set_param command $DIR/miaospeed-linux-$arch server -bind 127.0.0.1:45500 -mtls -token $TOKEN_PARAM -path $PATH_PARAM -ipv6
    procd_set_param respawn 3600 5 5
    procd_set_param stdout 1
    procd_set_param stderr 1
    procd_close_instance
}

stop_service() {
    return 0
}

restart_service() {
    stop_service
    start_service
}
EOF
cat <<EOF > /etc/init.d/frpc
#!/bin/sh /etc/rc.common
START=99
STOP=10
USE_PROCD=1
start_service() {
    procd_open_instance
    procd_set_param command $DIR/frpc -c $DIR/frpc.toml
    procd_set_param respawn 3600 5 5
    procd_set_param stdout 1
    procd_set_param stderr 1
    procd_close_instance
}

stop_service() {
    return 0
}

restart_service() {
    stop_service
    start_service
}
EOF
chmod +x /etc/init.d/miaospeed /etc/init.d/frpc
/etc/init.d/miaospeed enable
/etc/init.d/frpc enable
/etc/init.d/miaospeed start
/etc/init.d/frpc start
