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

# Check for activation code argument
if [ -z "$1" ]; then
    echo -e "${YELLOW}Usage: $0 <Activation_code>${NC}"
    exit 1
fi
ACTIVATION_CODE=$1

# Check if curl and jq are installed
for cmd in curl jq; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Error: $cmd is not installed. Please install it."
    exit 1
  fi
done

echo "Verifying activation code..."
API_RESPONSE=$(curl -s -X POST \
    -H "User-Agent: KoipyActivationClient/1.0" \
    -H "Content-Type: application/json" \
    -d "{\"code\": \"$ACTIVATION_CODE\"}" \
    https://kpanel.685763.xyz/activation/verify)

# Check if the API call returned anything and is valid JSON
if [ -z "$API_RESPONSE" ] || ! echo "$API_RESPONSE" | jq -e . >/dev/null 2>&1; then
    echo "Error: Failed to get a valid response from the activation server. Please check your network connection."
    exit 1
fi

# Check the status from the response
STATUS=$(echo "$API_RESPONSE" | jq -r .status)
if [ "$STATUS" -ne 0 ]; then
    echo "Error: Activation failed. Please check your activation code and try again."
    exit 1
fi

# Parse the successful response from the 'payload' object and trim hidden characters
PAYLOAD=$(echo "$API_RESPONSE" | jq .payload)
ADDRESS=$(echo "$PAYLOAD" | jq -r .address | tr -d '\r')

# Extract the server name and port
SERVER_NAME=$(echo "$ADDRESS" | cut -d: -f1)
FRPPORT_PARAM=$(echo "$ADDRESS" | cut -d: -f2)

# Validate the server name without displaying it
if [[ "$SERVER_NAME" != "a.haitunt.org" ]]; then
    echo "Error: Invalid server address received from the activation server."
    exit 1
fi

USER=$(echo "$PAYLOAD" | jq -r .user | tr -d '\r')
TOKEN_PARAM=$(echo "$PAYLOAD" | jq -r .token | tr -d '\r')
PATH_PARAM=$(echo "$PAYLOAD" | jq -r .path | tr -d '\r')

DEFAULT_DIR="/miaoko"
while true; do
    read -rp "$(echo -e "${YELLOW}Would you like to customize the installation path?(y/N): ${NC}")" CUSTOM_DIR
    CUSTOM_DIR=${CUSTOM_DIR:-N}
    if [[ "$CUSTOM_DIR" =~ ^[Yy]$ ]]; then
        read -rp "$(echo -e "${YELLOW}Please enter the installation path (e.g., /miaoko): ${NC}")" USER_DIR
        DIR=${USER_DIR:-$DEFAULT_DIR}
    else
        DIR=$DEFAULT_DIR
    fi

    echo ""
    echo -e "${GREEN}--------------------------------------------------${NC}"
    echo -e "${GREEN}Miaospeed configuration information for user: $USER ${NC}"
    echo -e "${GREEN}Installation directory: $DIR ${NC}"
    echo -e "${GREEN}FRP access port: $FRPPORT_PARAM ${NC}"
    echo -e "${GREEN}Path: $PATH_PARAM${NC}"
    echo -e "${GREEN}Token: $TOKEN_PARAM${NC}"
    echo -e "${GREEN}--------------------------------------------------${NC}"
    echo ""
    read -rp "$(echo -e "${YELLOW}Please confirm whether the above information is correct.(Y/n): ${NC}")" CONFIRM_CHOICE
    CONFIRM_CHOICE=${CONFIRM_CHOICE:-Y}
    if [[ "$CONFIRM_CHOICE" =~ ^[Yy]$ ]]; then
        break
    else
        echo -e "${YELLOW}Installation cancelled by user.${NC}"
        exit 1
    fi
done

mkdir -p "$DIR" || {
    echo "Failed to create directory: $DIR"
    exit 1
}
echo "Downloads will be saved to: $DIR"
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
    procd_set_param respawn
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
    procd_set_param respawn
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

echo -e "${GREEN}Installation complete!${NC}"
