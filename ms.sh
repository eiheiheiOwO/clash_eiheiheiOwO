#!/bin/bash
# =============================================================================
# ms.sh - miaospeed & frpc 三合一脚本 (install-debian / install-openwrt / update)
#
# 合并自:
#   msdebian.sh  (Debian + supervisor 安装)
#   msinstall.sh (OpenWrt + procd /etc/init.d 安装)
#   msupdate.sh  (全平台更新 + 每日 cron 自动更新)
#
# 用法:
#   ./ms.sh <激活码>                 自动检测平台并安装 (兼容旧用法)
#   ./ms.sh install <激活码>         自动检测平台并安装
#   ./ms.sh install-debian <激活码>  强制 Debian 安装 (supervisor)
#   ./ms.sh install-openwrt <激活码> 强制 OpenWrt 安装 (procd)
#   ./ms.sh update                  更新 miaospeed 与 frpc (含每日 cron)
#   ./ms.sh help                    显示帮助
#
# 选项:
#   -y, --yes  跳过交互确认 (非 TTY 环境自动生效)
#
# 兼容性: bash / busybox ash (OpenWrt) 均可运行
# =============================================================================

# ---------------- 颜色 (printf 赋值, 兼容 bash/ash, echo 无需 -e) ------------
GREEN=$(printf '\033[0;32m')
YELLOW=$(printf '\033[0;33m')
RED=$(printf '\033[0;31m')
NC=$(printf '\033[0m')

info() { printf "${GREEN}%s${NC}\n" "$*"; }
warn() { printf "${YELLOW}%s${NC}\n" "$*"; }
err()  { printf "${RED}%s${NC}\n" "$*"; }
die()  { err "$*"; exit 1; }

# ---------------- 全局配置 ----------------
SCRIPT_PATH=$(readlink -f "$0")
DEFAULT_DIR="/miaoko"
CACHE_DIR="/miaokocache"
ghproxy="https://gh.haitunt.org/"
ghapi="https://api.github.com/"
# 激活服务器地址, 可用环境变量 MS_API_URL 覆盖 (换域名无需改脚本)
API_URL="${MS_API_URL:-https://kpanel.685763.xyz/activation/verify}"
REPOS="AirportR/miaospeed fatedier/frp"
ASSUME_YES=0
SERVICE_MANAGER="unknown"
arch=""

# ---------------- 帮助 ----------------
usage() {
    cat <<'EOF'
用法:
  ./ms.sh <激活码>                 自动检测平台并安装 (兼容旧用法)
  ./ms.sh install <激活码>         自动检测平台并安装
  ./ms.sh install-debian <激活码>   Debian 安装 (supervisor)
  ./ms.sh install-openwrt <激活码>  OpenWrt 安装 (procd /etc/init.d)
  ./ms.sh update                   更新 miaospeed 与 frpc (并设置每日 cron)
  ./ms.sh help                     显示帮助

选项:
  -y, --yes  跳过交互确认 (非 TTY 环境自动生效)
EOF
}

# ---------------- LOGO ----------------
banner() {
    printf "\033[2J\033[H"
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
    echo "${YELLOW}                                        三合一: Debian/OpenWrt 安装 + 自动更新                       ${NC}"
}

# ---------------- 基础检查 ----------------
check_root() {
    [ "$(id -u)" -eq 0 ] || die "必须以 root 运行, 请使用 sudo"
}

detect_platform() {
    if [ -f /etc/rc.common ]; then
        echo "openwrt"
    elif command -v supervisord >/dev/null 2>&1 || [ -d /etc/supervisor/conf.d ]; then
        echo "debian"
    else
        echo "unknown"
    fi
}

check_deps() {
    local missing="" pkg
    for pkg in curl jq tar; do
        command -v "$pkg" >/dev/null 2>&1 || missing="$missing $pkg"
    done
    if [ "$PLATFORM" = "debian" ]; then
        command -v supervisorctl >/dev/null 2>&1 || missing="$missing supervisor"
    fi
    if [ -n "$missing" ]; then
        err "缺少依赖:${missing# }"
        if [ "$PLATFORM" = "debian" ]; then
            warn "请执行: apt-get update && apt-get install -y${missing}"
        else
            warn "请先用 opkg 安装缺失依赖"
        fi
        exit 1
    fi
    info "依赖检查通过"
}

detect_arch() {
    local raw
    raw=$(uname -m)
    case "$raw" in
        x86_64|amd64) arch="amd64" ;;
        aarch64|arm64) arch="arm64" ;;
        *) die "不支持的架构: $raw" ;;
    esac
    info "检测到架构: $arch"
}

# ---------------- 激活 API ----------------
# 合并两个安装脚本的校验逻辑:
#   msdebian: 校验 user/token/path/address 完整 + address 格式
#   msinstall: 校验 .status == 0 + JSON 合法性
activate() {
    local code="$1" resp user token path addr frp_port v
    warn "正在通过激活码获取配置..."
    resp=$(curl -s -X POST \
        -H "User-Agent: KoipyActivationClient/1.0" \
        -H "Content-Type: application/json" \
        -d "{\"code\": \"$code\"}" \
        "$API_URL") || die "无法连接激活服务器"
    [ -n "$resp" ] || die "激活服务器返回空响应"
    echo "$resp" | jq -e . >/dev/null 2>&1 || die "激活服务器响应不是有效 JSON"
    if [ "$(echo "$resp" | jq -r .status)" != "0" ]; then
        msg=$(echo "$resp" | jq -r '.message // "激活失败"' | tr -d '\r')
        case "$msg" in
            *占用*)
                die "激活失败: 该后端端口已被占用(可能已有实例在线)。请先停止旧实例后重试，或联系管理员处理。"
                ;;
            *)
                die "激活失败: $msg"
                ;;
        esac
    fi
    user=$(echo "$resp" | jq -r '.payload.user' | tr -d '\r')
    token=$(echo "$resp" | jq -r '.payload.token' | tr -d '\r')
    path=$(echo "$resp" | jq -r '.payload.path' | tr -d '\r')
    addr=$(echo "$resp" | jq -r '.payload.address' | tr -d '\r')
    for v in "$user" "$token" "$path" "$addr"; do
        [ -n "$v" ] && [ "$v" != "null" ] || die "激活码无效或服务器返回信息不完整"
    done
    case "$addr" in
        a.haitunt.org:*) frp_port=${addr#a.haitunt.org:} ;;
        *) die "服务器返回的地址无效: $addr" ;;
    esac
    USER="$user"; TOKEN_PARAM="$token"; PATH_PARAM="$path"; FRPPORT_PARAM="$frp_port"
    info "配置获取成功: 用户=$USER 端口=$FRPPORT_PARAM path=$PATH_PARAM"
}

# ---------------- 版本获取与下载 (三脚本共用逻辑) ----------------
get_latest_url() {
    local repo="$1" api_url url
    api_url="${ghapi}repos/${repo}/releases/latest"
    url=$(curl -s "$api_url" \
        | jq -r --arg arch "$arch" '.assets[]
            | select(.name | contains("linux") and contains($arch) and endswith(".tar.gz"))
            | .browser_download_url' \
        | head -n 1)
    if [ -z "$url" ] || [ "$url" = "null" ]; then
        err "未找到 $repo 的 Linux tar.gz 下载链接"
        return 1
    fi
    echo "$url"
}

download_and_extract() {
    local dest="$1" repo url filename archive nested_dir
    for repo in $REPOS; do
        info "处理仓库: $repo ..."
        url=$(get_latest_url "$repo") || return 1
        filename=$(basename "$url")
        archive="$dest/$filename"
        info "下载: ${ghproxy}${url}"
        curl -sL -o "$archive" "${ghproxy}${url}" || { err "下载失败: $filename"; return 1; }
        tar zxf "$archive" -C "$dest" >/dev/null 2>&1 || { err "解压失败: $archive"; return 1; }
        rm -f "$archive"
        if [ "$repo" = "fatedier/frp" ]; then
            nested_dir=$(find "$dest" -maxdepth 1 -type d -name "frp*linux*${arch}*" | head -n 1)
            if [ -n "$nested_dir" ] && [ -f "$nested_dir/frpc" ]; then
                mv "$nested_dir/frpc" "$dest/" 2>/dev/null
                rm -rf "$nested_dir"
                info "frpc 已提取到 $dest"
            fi
        fi
    done
}

# ---------------- 配置文件 ----------------
write_frpc_toml() {
    local dir="$1"
    cat > "$dir/frpc.toml" <<EOF
serverAddr = "a.haitunt.org"
serverPort = 10102
auth.method = "token"
auth.token = "OUaW6oLUSzNjmSb2"
dnsServer = "119.29.29.29"

[[proxies]]
name = "$USER.$FRPPORT_PARAM"
type = "tcp"
localIP = "127.0.0.1"
localPort = 45500
remotePort = $FRPPORT_PARAM
EOF
    info "frpc.toml 已生成: $dir/frpc.toml"
}

# ---------------- 服务安装 ----------------
install_service_debian() {
    local dir="$1"
    cat > /etc/supervisor/conf.d/miaospeed.conf <<EOF
[program:miaospeed]
command=$dir/miaospeed-linux-$arch server -bind 127.0.0.1:45500 -mtls -token $TOKEN_PARAM -path $PATH_PARAM -ipv6
directory=$dir
autostart=true
autorestart=true
user=root
stdout_logfile=/var/log/supervisor/miaospeed.log
stderr_logfile=/var/log/supervisor/miaospeed_err.log
EOF

    cat > /etc/supervisor/conf.d/frpc.conf <<EOF
[program:frpc]
command=$dir/frpc -c $dir/frpc.toml
directory=$dir
autostart=true
autorestart=true
user=root
stdout_logfile=/var/log/supervisor/frpc.log
stderr_logfile=/var/log/supervisor/frpc_err.log
EOF
    info "supervisor 配置已写入 /etc/supervisor/conf.d/"
    supervisorctl reread
    supervisorctl update
}

install_service_openwrt() {
    local dir="$1"
    cat > /etc/init.d/miaospeed <<EOF
#!/bin/sh /etc/rc.common
START=99
STOP=10
USE_PROCD=1
start_service() {
    procd_open_instance
    procd_set_param command $dir/miaospeed-linux-$arch server -bind 127.0.0.1:45500 -mtls -token $TOKEN_PARAM -path $PATH_PARAM -ipv6
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

    cat > /etc/init.d/msfrpc <<EOF
#!/bin/sh /etc/rc.common
START=99
STOP=10
USE_PROCD=1
start_service() {
    procd_open_instance
    procd_set_param command $dir/frpc -c $dir/frpc.toml
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
    chmod +x /etc/init.d/miaospeed /etc/init.d/msfrpc
    /etc/init.d/miaospeed enable
    /etc/init.d/msfrpc enable
    /etc/init.d/miaospeed start
    /etc/init.d/msfrpc start
    info "OpenWrt init.d 服务已启用并启动"
}

# ---------------- 服务停止/启动 (更新用, 自动识别) ----------------
stop_services() {
    warn "停止服务..."
    if command -v supervisorctl >/dev/null 2>&1; then
        echo "检测到 supervisor, 停止 miaospeed/frpc..."
        supervisorctl stop miaospeed frpc >/dev/null 2>&1 || true
        SERVICE_MANAGER="supervisord"
    elif ps | grep -v grep | grep -q 'supervisord'; then
        echo "检测到 supervisord 进程 (无 supervisorctl), 强制停止..."
        kill -9 "$(ps | grep '[s]upervisord' | awk '{print $1}')" 2>/dev/null || true
        SERVICE_MANAGER="supervisord"
    elif [ -f /etc/init.d/miaospeed ] && [ -f /etc/init.d/msfrpc ]; then
        echo "检测到 OpenWrt 服务, 停止..."
        /etc/init.d/miaospeed stop >/dev/null 2>&1
        /etc/init.d/msfrpc stop >/dev/null 2>&1
        SERVICE_MANAGER="openwrt"
    else
        warn "未检测到已知服务管理器"
        SERVICE_MANAGER="unknown"
    fi
}

start_services() {
    info "启动服务..."
    case "$SERVICE_MANAGER" in
        supervisord)
            if command -v supervisorctl >/dev/null 2>&1; then
                supervisorctl reread >/dev/null 2>&1
                supervisorctl update >/dev/null 2>&1
                supervisorctl start miaospeed frpc >/dev/null 2>&1 || true
            else
                service supervisord start >/dev/null 2>&1 || true
            fi
            ;;
        openwrt)
            /etc/init.d/miaospeed start >/dev/null 2>&1
            /etc/init.d/msfrpc start >/dev/null 2>&1
            ;;
        *)
            warn "未知服务管理器, 请手动启动服务"
            ;;
    esac
}

# ---------------- 每日自动更新 cron ----------------
setup_cron() {
    local minute hour cmd
    info "设置每日自动更新 cron 任务..."
    minute=$(( RANDOM % 60 ))
    hour=4
    cmd="$minute $hour * * * $SCRIPT_PATH update"
    (crontab -l 2>/dev/null | grep -v "$SCRIPT_PATH") > /tmp/crontab.tmp
    echo "$cmd" >> /tmp/crontab.tmp
    crontab /tmp/crontab.tmp
    rm -f /tmp/crontab.tmp
    info "Cron 任务已设置: 每天 ${hour}:${minute} 自动执行 $SCRIPT_PATH update"
}

# ---------------- 安装流程 ----------------
cmd_install() {
    local code="$1" platform="$2" dir custom confirm
    [ -n "$code" ] || die "缺少激活码。用法: ./ms.sh install <激活码>"
    check_root
    if [ "$platform" = "auto" ]; then
        platform=$(detect_platform)
        [ "$platform" != "unknown" ] || die "无法自动识别平台, 请用 install-debian / install-openwrt 指定"
    fi
    PLATFORM="$platform"
    info "目标平台: $platform"
    check_deps
    detect_arch
    activate "$code"

    # 安装路径选择 + 信息确认 (交互式, -y 或非 TTY 时用默认值)
    dir="$DEFAULT_DIR"
    if [ "$ASSUME_YES" -eq 1 ] || [ ! -t 0 ]; then
        info "非交互模式, 使用默认安装目录: $dir"
    else
        while true; do
            printf "${YELLOW}是否自定义安装路径? (y/N): ${NC}"
            read -r custom
            custom=${custom:-N}
            if [ "$custom" = "y" ] || [ "$custom" = "Y" ]; then
                printf "${YELLOW}请输入安装路径 (如 /miaoko): ${NC}"
                read -r dir
                dir=${dir:-$DEFAULT_DIR}
            else
                dir="$DEFAULT_DIR"
            fi
            echo ""
            info "--------------------------------------------------"
            info "用户: $USER"
            info "安装目录: $dir"
            info "FRP 端口: $FRPPORT_PARAM"
            info "Path: $PATH_PARAM"
            info "Token: $TOKEN_PARAM"
            info "--------------------------------------------------"
            printf "${YELLOW}确认以上信息正确? (Y/n): ${NC}"
            read -r confirm
            confirm=${confirm:-Y}
            if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
                break
            else
                die "安装已取消"
            fi
        done
    fi

    mkdir -p "$dir" || die "无法创建目录: $dir"
    info "下载将保存到: $dir"
    download_and_extract "$dir" || die "下载/解压失败"

    # 校验二进制 (修复 msinstall 缺少 chmod 与缺失校验的问题)
    [ -s "$dir/miaospeed-linux-$arch" ] || die "miaospeed 二进制无效或缺失"
    [ -s "$dir/frpc" ] || die "frpc 二进制无效或缺失"

    info "清理目录, 仅保留 miaospeed* 与 frpc ..."
    ( cd "$dir" && for item in *; do
        case "$item" in
            miaospeed*|frpc) ;;
            *) rm -rf "$item" ;;
        esac
    done )
    chmod +x "$dir"/miaospeed-linux-"$arch" "$dir"/frpc

    write_frpc_toml "$dir"
    if [ "$platform" = "debian" ]; then
        install_service_debian "$dir"
    else
        install_service_openwrt "$dir"
    fi
    info "安装完成!"
    if [ "$platform" = "debian" ]; then
        info "查看状态: supervisorctl status"
    else
        info "查看状态: /etc/init.d/miaospeed status"
    fi
}

# ---------------- 更新流程 ----------------
cmd_update() {
    check_root
    command -v curl >/dev/null 2>&1 || die "缺少 curl"
    command -v jq >/dev/null 2>&1 || die "缺少 jq"
    [ -f "$DEFAULT_DIR/frpc" ] || die "未检测到已安装的 frpc ($DEFAULT_DIR/frpc), 请先安装"

    detect_arch
    info "创建缓存目录: $CACHE_DIR"
    mkdir -p "$CACHE_DIR" || die "无法创建缓存目录: $CACHE_DIR"
    if ! download_and_extract "$CACHE_DIR"; then
        rm -rf "$CACHE_DIR"
        die "下载/解压失败, 已清理缓存"
    fi
    if [ ! -s "$CACHE_DIR/miaospeed-linux-$arch" ]; then
        rm -rf "$CACHE_DIR"
        die "下载的 miaospeed 无效或为空, 已中止更新"
    fi
    if [ ! -s "$CACHE_DIR/frpc" ]; then
        rm -rf "$CACHE_DIR"
        die "下载的 frpc 无效或为空, 已中止更新"
    fi
    info "文件验证成功, 准备应用更新..."

    stop_services
    info "清理旧版本并替换..."
    rm -f "$DEFAULT_DIR/miaospeed-linux-$arch" "$DEFAULT_DIR/frpc"
    cp "$CACHE_DIR/miaospeed-linux-$arch" "$DEFAULT_DIR/miaospeed-linux-$arch"
    cp "$CACHE_DIR/frpc" "$DEFAULT_DIR/frpc"
    chmod +x "$DEFAULT_DIR/miaospeed-linux-$arch" "$DEFAULT_DIR/frpc"
    rm -rf "$CACHE_DIR"
    info "更新完成!"

    if crontab -l 2>/dev/null | grep -q "$SCRIPT_PATH"; then
        info "Cron 任务已存在, 无需重复设置"
    else
        setup_cron
    fi
    start_services
    info "服务已启动"
}

# ---------------- 入口 ----------------
main() {
    local cmd="" code=""
    banner
    while [ $# -gt 0 ]; do
        case "$1" in
            help|-h|--help) usage; exit 0 ;;
            -y|--yes) ASSUME_YES=1; shift ;;
            update|-u|--update) cmd="update"; shift ;;
            install-debian) cmd="install-debian"; shift ;;
            install-openwrt) cmd="install-openwrt"; shift ;;
            install) cmd="install"; shift ;;
            *)
                # 首参不是已知命令时视为激活码 (兼容旧用法: ./ms.sh CODE)
                [ -z "$cmd" ] && cmd="install"
                code="$1"
                shift
                ;;
        esac
    done
    case "$cmd" in
        update) cmd_update ;;
        install-debian) cmd_install "$code" debian ;;
        install-openwrt) cmd_install "$code" openwrt ;;
        install) cmd_install "$code" auto ;;
        *) usage; exit 1 ;;
    esac
}

main "$@"
