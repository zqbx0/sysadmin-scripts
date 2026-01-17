#!/usr/bin/env bash
# Sing-box Version v1.0.1

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# GitHub proxy for faster downloads
GITHUB_PROXY=('' 'https://v6.gh-proxy.org/' 'https://gh-proxy.com/' 'https://hub.glowp.xyz/' 'https://proxy.vvvv.ee/' 'https://ghproxy.lvedong.eu.org/')

# Core variables
SCRIPT_NAME="sing-box"
SCRIPT_VERSION="1.0.1"
WORK_DIR='/etc/sing-box'
BIN_FILE="/usr/local/bin/sing-box"
SERVICE_FILE="/etc/systemd/system/sing-box.service"
LOG_FILE="/var/log/sing-box.log"
CONFIG_DIR="$WORK_DIR/conf"
SUBSCRIBE_DIR="$WORK_DIR/subscribe"
TEMP_DIR='/tmp/sing-box'
BACKUP_DIR="/backup/sing-box"

# Port configuration
START_PORT_DEFAULT='8881'
MIN_PORT=100
MAX_PORT=65520
MIN_HOPPING_PORT=10000
MAX_HOPPING_PORT=65535
CONSECUTIVE_PORTS=11  # Number of protocols

# TLS and Domain settings
TLS_SERVER_DEFAULT='addons.mozilla.org'
CDN_DOMAIN=("skk.moe" "ip.sb" "time.is" "cfip.xxxxxxxx.tk" "bestcf.top" "cdn.2020111.xyz" "xn--b6gac.eu.org" "cf.090227.xyz")

# Protocol support - enhanced list
PROTOCOL_LIST=("XTLS + reality" "hysteria2" "tuic" "ShadowTLS" "shadowsocks" "trojan" "vmess + ws" "vless + ws + tls" "H2 + reality" "gRPC + reality" "AnyTLS")
PROTOCOLS=("xtls+reality" "hysteria2" "tuic" "shadowtls" "shadowsocks" "trojan" "vmess+ws" "vless+ws+tls" "h2+reality" "grpc+reality" "anytls")
PROTOCOL_TAGS=("xtls-reality" "hysteria2" "tuic" "shadowtls" "shadowsocks" "trojan" "vmess-ws" "vless-ws-tls" "h2-reality" "grpc-reality" "anytls")
NODE_TAG=("xtls-reality" "hysteria2" "tuic" "ShadowTLS" "shadowsocks" "trojan" "vmess-ws" "vless-ws-tls" "h2-reality" "grpc-reality" "anytls")

# Subscription templates
SUBSCRIBE_TEMPLATE="https://raw.githubusercontent.com/fscarmen/client_template/main"

# Version control
DEFAULT_NEWEST_VERSION='1.13.0-alpha.33'

# Messages
ERROR_ROOT="This script must be run as root"
ERROR_OS="Unsupported operating system"
ERROR_ARCH="Unsupported architecture"
INFO_START="Starting installation..."
INFO_DOWNLOAD="Downloading sing-box..."
INFO_INSTALL="Installing sing-box..."
INFO_SUCCESS="✅ Installation successful!"
INFO_FAILED="❌ Installation failed"
INFO_RUNNING="Service is running"
INFO_STOPPED="Service is stopped"
INFO_UNINSTALL="Uninstalling..."
INFO_UPDATE="Checking for updates..."
INFO_NO_UPDATE="Already up to date"
INFO_UPDATED="Updated successfully"
INFO_BACKUP="Creating backup..."
INFO_RESTORE="Restoring backup..."
INFO_USER_ADD="Adding user..."
INFO_USER_LIST="User list:"
INFO_PORT_CHANGE="Changing port..."
INFO_SUBSCRIBE="Generating subscription..."
INFO_CUSTOM_PORT="Custom port configuration"
INFO_CDN_TEST="Testing CDN domains..."
INFO_PROXY_TEST="Testing GitHub proxies..."

# Functions
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }
info() { echo -e "${GREEN}[INFO]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
step() { echo -e "${BLUE}[STEP]${NC} $*"; }
debug() { echo -e "${CYAN}[DEBUG]${NC} $*"; }
highlight() { echo -e "${PURPLE}[*]${NC} $*"; }

check_root() {
    [[ $EUID -ne 0 ]] && error "$ERROR_ROOT"
}

check_system() {
    if [[ -f /etc/redhat-release ]]; then
        SYSTEM="centos"
    elif grep -q "Ubuntu" /etc/os-release; then
        SYSTEM="ubuntu"
    elif grep -q "Debian" /etc/os-release; then
        SYSTEM="debian"
    elif grep -q "Alpine" /etc/os-release; then
        SYSTEM="alpine"
    else
        SYSTEM="unknown"
    fi
    [[ "$SYSTEM" == "unknown" ]] && error "$ERROR_OS"
}

check_arch() {
    case "$(uname -m)" in
        x86_64|amd64) ARCH="amd64" ;;
        aarch64|arm64) ARCH="arm64" ;;
        armv7l) ARCH="armv7" ;;
        *) error "$ERROR_ARCH: $(uname -m)" ;;
    esac
}

test_github_proxy() {
    local test_url="https://raw.githubusercontent.com/SagerNet/sing-box/main/README.md"
    local fastest_proxy=""
    local fastest_time=99999
    
    step "$INFO_PROXY_TEST"
    
    for proxy in "${GITHUB_PROXY[@]}"; do
        local url="${proxy}${test_url}"
        local start_time=$(date +%s%N)
        
        if curl -s --connect-timeout 3 "$url" > /dev/null 2>&1; then
            local end_time=$(date +%s%N)
            local duration=$(( (end_time - start_time) / 1000000 ))
            
            if [[ $duration -lt $fastest_time ]]; then
                fastest_time=$duration
                fastest_proxy="$proxy"
            fi
            
            info "Proxy: ${proxy:-direct} - ${duration}ms"
        else
            warn "Proxy: ${proxy:-direct} - Failed"
        fi
    done
    
    if [[ -n "$fastest_proxy" ]]; then
        GITHUB_PROXY_URL="$fastest_proxy"
        info "Selected fastest proxy: ${fastest_proxy:-direct}"
    else
        GITHUB_PROXY_URL=""
        warn "No working proxy found, using direct connection"
    fi
}

test_cdn_domains() {
    step "$INFO_CDN_TEST"
    local fastest_domain=""
    local fastest_time=99999
    
    for domain in "${CDN_DOMAIN[@]}"; do
        local start_time=$(date +%s%N)
        
        if ping -c 1 -W 2 "$domain" > /dev/null 2>&1; then
            local end_time=$(date +%s%N)
            local duration=$(( (end_time - start_time) / 1000000 ))
            
            if [[ $duration -lt $fastest_time ]]; then
                fastest_time=$duration
                fastest_domain="$domain"
            fi
            
            info "CDN: $domain - ${duration}ms"
        else
            warn "CDN: $domain - Unreachable"
        fi
    done
    
    if [[ -n "$fastest_domain" ]]; then
        CDN_DOMAIN_SELECTED="$fastest_domain"
        info "Selected fastest CDN: $fastest_domain"
    else
        CDN_DOMAIN_SELECTED="ip.sb"
        warn "No CDN available, using default"
    fi
}

install_dependencies() {
    step "Installing dependencies..."
    case $SYSTEM in
        ubuntu|debian)
            apt-get update
            apt-get install -y curl wget tar jq openssl net-tools iputils-ping
            ;;
        centos)
            yum install -y curl wget tar jq openssl net-tools iputils
            ;;
        alpine)
            apk add --no-cache curl wget tar jq openssl net-tools iputils
            ;;
    esac
}

get_latest_version() {
    local api_url="https://api.github.com/repos/SagerNet/sing-box/releases/latest"
    local full_url="${GITHUB_PROXY_URL}${api_url}"
    
    local version=$(curl -s "$full_url" | \
        grep '"tag_name":' | cut -d '"' -f 4 | sed 's/^v//' 2>/dev/null)
    
    if [[ -z "$version" ]]; then
        warn "Failed to fetch latest version, using default: $DEFAULT_NEWEST_VERSION"
        version="$DEFAULT_NEWEST_VERSION"
    fi
    
    echo "$version"
}

download_singbox() {
    local version=$1
    local base_url="https://github.com/SagerNet/sing-box/releases/download/v${version}"
    local filename="sing-box-${version}-linux-${ARCH}.tar.gz"
    local url="${base_url}/${filename}"
    local proxy_url="${GITHUB_PROXY_URL}${url}"
    
    step "$INFO_DOWNLOAD"
    step "Version: $version, Arch: $ARCH"
    
    # Try proxy first, then direct
    if wget -q --timeout=30 -O "$TEMP_DIR/sing-box.tar.gz" "$proxy_url"; then
        info "Downloaded via proxy"
    elif wget -q --timeout=30 -O "$TEMP_DIR/sing-box.tar.gz" "$url"; then
        info "Downloaded directly"
    else
        error "Download failed for both proxy and direct"
    fi
    
    tar -xzf "$TEMP_DIR/sing-box.tar.gz" -C "$TEMP_DIR"
    
    # Find the binary in extracted directory
    local binary=$(find "$TEMP_DIR" -name "sing-box" -type f | head -1)
    [[ -f "$binary" ]] || error "Binary not found"
    
    cp "$binary" "$BIN_FILE"
    chmod +x "$BIN_FILE"
}

create_directories() {
    mkdir -p "$WORK_DIR" "$CONFIG_DIR" "$SUBSCRIBE_DIR" "$BACKUP_DIR" "$(dirname "$LOG_FILE")"
}

generate_comprehensive_config() {
    local start_port=${1:-$START_PORT_DEFAULT}
    
    cat > "$WORK_DIR/config.json" << CONFIG
{
  "log": {
    "level": "info",
    "output": "$LOG_FILE",
    "timestamp": true
  },
  "dns": {
    "servers": [
      {
        "tag": "google",
        "address": "tls://8.8.8.8",
        "detour": "direct"
      },
      {
        "tag": "local",
        "address": "223.5.5.5",
        "detour": "direct"
      }
    ],
    "strategy": "ipv4_only"
  },
  "ntp": {
    "enabled": true,
    "server": "time.apple.com",
    "server_port": 123
  },
  "inbounds": [
    {
      "type": "mixed",
      "tag": "mixed-proxy",
      "listen": "0.0.0.0",
      "listen_port": $start_port,
      "sniff": true,
      "sniff_override_destination": true,
      "users": []
    }
  ],
  "outbounds": [
    {
      "type": "direct",
      "tag": "direct"
    },
    {
      "type": "block",
      "tag": "block"
    },
    {
      "type": "dns",
      "tag": "dns-out"
    }
  ],
  "route": {
    "auto_detect_interface": true,
    "rules": [
      {
        "protocol": "dns",
        "outbound": "dns-out"
      },
      {
        "ip_is_private": true,
        "outbound": "direct"
      }
    ]
  }
}
CONFIG
}

generate_protocol_config() {
    local protocol=$1
    local port=$2
    local uuid=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || openssl rand -hex 16)
    local short_id=$(openssl rand -hex 8)
    
    case "$protocol" in
        "xtls+reality")
            cat > "$CONFIG_DIR/${protocol}_${port}.json" << CONFIG
{
  "type": "vless",
  "tag": "inbound-${protocol}",
  "listen": "0.0.0.0",
  "listen_port": $port,
  "users": [
    {
      "uuid": "$uuid",
      "flow": "xtls-rprx-vision"
    }
  ],
  "tls": {
    "enabled": true,
    "server_name": "$TLS_SERVER_DEFAULT",
    "reality": {
      "enabled": true,
      "handshake": {
        "server": "$TLS_SERVER_DEFAULT",
        "server_port": 443
      },
      "private_key": "",
      "short_id": ["$short_id"]
    }
  }
}
CONFIG
            ;;
        "hysteria2")
            cat > "$CONFIG_DIR/${protocol}_${port}.json" << CONFIG
{
  "type": "hysteria2",
  "tag": "inbound-${protocol}",
  "listen": "0.0.0.0",
  "listen_port": $port,
  "users": [
    {
      "password": "$uuid"
    }
  ],
  "tls": {
    "enabled": true,
    "alpn": ["h3"]
  }
}
CONFIG
            ;;
        "tuic")
            cat > "$CONFIG_DIR/${protocol}_${port}.json" << CONFIG
{
  "type": "tuic",
  "tag": "inbound-${protocol}",
  "listen": "0.0.0.0",
  "listen_port": $port,
  "users": [
    {
      "uuid": "$uuid",
      "password": "$(openssl rand -hex 8)"
    }
  ],
  "tls": {
    "enabled": true
  }
}
CONFIG
            ;;
        "shadowtls")
            cat > "$CONFIG_DIR/${protocol}_${port}.json" << CONFIG
{
  "type": "shadowtls",
  "tag": "inbound-${protocol}",
  "listen": "0.0.0.0",
  "listen_port": $port,
  "users": [
    {
      "password": "$uuid"
    }
  ],
  "tls": {
    "enabled": true,
    "server_name": "$TLS_SERVER_DEFAULT"
  }
}
CONFIG
            ;;
        "shadowsocks")
            cat > "$CONFIG_DIR/${protocol}_${port}.json" << CONFIG
{
  "type": "shadowsocks",
  "tag": "inbound-${protocol}",
  "listen": "0.0.0.0",
  "listen_port": $port,
  "method": "2022-blake3-aes-128-gcm",
  "password": "$uuid"
}
CONFIG
            ;;
        "trojan")
            cat > "$CONFIG_DIR/${protocol}_${port}.json" << CONFIG
{
  "type": "trojan",
  "tag": "inbound-${protocol}",
  "listen": "0.0.0.0",
  "listen_port": $port,
  "users": [
    {
      "password": "$uuid"
    }
  ],
  "tls": {
    "enabled": true
  }
}
CONFIG
            ;;
        "vmess+ws")
            cat > "$CONFIG_DIR/${protocol}_${port}.json" << CONFIG
{
  "type": "vmess",
  "tag": "inbound-${protocol}",
  "listen": "0.0.0.0",
  "listen_port": $port,
  "users": [
    {
      "uuid": "$uuid",
      "alterId": 0
    }
  ],
  "transport": {
    "type": "ws",
    "path": "/vmess"
  }
}
CONFIG
            ;;
        "vless+ws+tls")
            cat > "$CONFIG_DIR/${protocol}_${port}.json" << CONFIG
{
  "type": "vless",
  "tag": "inbound-${protocol}",
  "listen": "0.0.0.0",
  "listen_port": $port,
  "users": [
    {
      "uuid": "$uuid",
      "flow": ""
    }
  ],
  "tls": {
    "enabled": true
  },
  "transport": {
    "type": "ws",
    "path": "/vless"
  }
}
CONFIG
            ;;
        "h2+reality")
            cat > "$CONFIG_DIR/${protocol}_${port}.json" << CONFIG
{
  "type": "vless",
  "tag": "inbound-${protocol}",
  "listen": "0.0.0.0",
  "listen_port": $port,
  "users": [
    {
      "uuid": "$uuid",
      "flow": ""
    }
  ],
  "transport": {
    "type": "http"
  },
  "tls": {
    "enabled": true,
    "reality": {
      "enabled": true,
      "handshake": {
        "server": "$TLS_SERVER_DEFAULT",
        "server_port": 443
      }
    }
  }
}
CONFIG
            ;;
        "grpc+reality")
            cat > "$CONFIG_DIR/${protocol}_${port}.json" << CONFIG
{
  "type": "vless",
  "tag": "inbound-${protocol}",
  "listen": "0.0.0.0",
  "listen_port": $port,
  "users": [
    {
      "uuid": "$uuid",
      "flow": ""
    }
  ],
  "transport": {
    "type": "grpc",
    "service_name": "GunService"
  },
  "tls": {
    "enabled": true,
    "reality": {
      "enabled": true,
      "handshake": {
        "server": "$TLS_SERVER_DEFAULT",
        "server_port": 443
      }
    }
  }
}
CONFIG
            ;;
        "anytls")
            cat > "$CONFIG_DIR/${protocol}_${port}.json" << CONFIG
{
  "type": "trojan",
  "tag": "inbound-${protocol}",
  "listen": "0.0.0.0",
  "listen_port": $port,
  "users": [
    {
      "password": "$uuid"
    }
  ],
  "tls": {
    "enabled": true,
    "alpn": ["h2", "http/1.1"],
    "utls": {
      "enabled": true,
      "fingerprint": "chrome"
    }
  }
}
CONFIG
            ;;
    esac
}

setup_multiple_protocols() {
    step "Setting up multiple protocols..."
    
    local start_port=$START_PORT_DEFAULT
    local configs=()
    
    for i in "${!PROTOCOLS[@]}"; do
        local protocol="${PROTOCOLS[$i]}"
        local port=$((start_port + i))
        
        info "Setting up $protocol on port $port"
        generate_protocol_config "$protocol" "$port"
        configs+=("\"$CONFIG_DIR/${protocol}_${port}.json\"")
    done
    
    # Create main config that includes all protocol configs
    cat > "$WORK_DIR/config.json" << MAIN_CONFIG
{
  "log": {
    "level": "info",
    "output": "$LOG_FILE"
  },
  "route": {
    "auto_detect_interface": true
  },
  "inbounds": [
    {
      "type": "mixed",
      "tag": "mixed-proxy",
      "listen": "0.0.0.0",
      "listen_port": $start_port,
      "sniff": true
    }
  ],
  "outbounds": [
    {
      "type": "direct",
      "tag": "direct"
    }
  ],
  "experimental": {
    "clash_api": {
      "external_controller": "127.0.0.1:9090",
      "secret": ""
    }
  }
}
MAIN_CONFIG
    
    highlight "Protocol setup complete!"
    for i in "${!PROTOCOLS[@]}"; do
        local port=$((start_port + i))
        echo "  ${PROTOCOL_LIST[$i]} - Port: $port"
    done
}

create_service() {
    cat > "$SERVICE_FILE" << SERVICE
[Unit]
Description=sing-box Service
After=network.target nss-lookup.target

[Service]
Type=simple
User=root
ExecStart=$BIN_FILE run -c $WORK_DIR/config.json -D $WORK_DIR
ExecReload=/bin/kill -HUP \$MAINPID
Restart=on-failure
RestartSec=10
LimitNOFILE=infinity

[Install]
WantedBy=multi-user.target
SERVICE
}

start_service() {
    systemctl daemon-reload
    systemctl enable "$SCRIPT_NAME"
    systemctl start "$SCRIPT_NAME"
    sleep 2
}

check_service() {
    if systemctl is-active --quiet "$SCRIPT_NAME"; then
        info "$INFO_RUNNING"
        return 0
    else
        warn "$INFO_STOPPED"
        return 1
    fi
}

add_user() {
    echo
    highlight "Add New User"
    echo "================"
    
    read -p "Enter username: " username
    read -sp "Enter password: " password
    echo
    
    echo "Select protocol:"
    for i in "${!PROTOCOL_LIST[@]}"; do
        echo "$((i+1))) ${PROTOCOL_LIST[$i]}"
    done
    
    read -p "Choice (1-${#PROTOCOL_LIST[@]}): " proto_choice
    
    local index=$((proto_choice - 1))
    if [[ $index -lt 0 || $index -ge ${#PROTOCOLS[@]} ]]; then
        warn "Invalid choice, using first protocol"
        index=0
    fi
    
    local protocol="${PROTOCOLS[$index]}"
    local port=$((START_PORT_DEFAULT + index))
    local uuid=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || openssl rand -hex 16)
    
    info "$INFO_USER_ADD"
    echo "Username: $username"
    echo "Protocol: ${PROTOCOL_LIST[$index]}"
    echo "Port: $port"
    echo "UUID/Password: $uuid"
    
    # Save user info
    local user_file="$WORK_DIR/users.json"
    if [[ ! -f "$user_file" ]]; then
        echo '{"users": []}' > "$user_file"
    fi
    
    local user_config="{\"username\":\"$username\",\"password\":\"$password\",\"protocol\":\"$protocol\",\"node_tag\":\"${NODE_TAG[$index]}\",\"port\":$port,\"uuid\":\"$uuid\",\"added\":\"$(date)\"}"
    
    if command -v jq >/dev/null; then
        jq ".users += [$user_config]" "$user_file" > "$user_file.tmp"
        mv "$user_file.tmp" "$user_file"
    else
        echo "$user_config" >> "$user_file"
    fi
    
    generate_user_subscription "$username" "$protocol" "$port" "$uuid"
}

generate_user_subscription() {
    local username=$1
    local protocol=$2
    local port=$3
    local uuid=$4
    local server_ip=$(curl -s "${GITHUB_PROXY_URL}https://${CDN_DOMAIN_SELECTED}" 2>/dev/null || echo "127.0.0.1")
    
    mkdir -p "$SUBSCRIBE_DIR/$username"
    
    cat > "$SUBSCRIBE_DIR/$username/config.json" << SUB_CONFIG
{
  "server": "$server_ip",
  "server_port": $port,
  "uuid": "$uuid",
  "protocol": "$protocol",
  "tag": "${NODE_TAG[0]}",
  "tls": {
    "enabled": true,
    "server_name": "$TLS_SERVER_DEFAULT"
  }
}
SUB_CONFIG
    
    cat > "$SUBSCRIBE_DIR/$username/README.md" << README
# Subscription for $username

## Server Information
- IP: $server_ip
- Port: $port
- Protocol: $protocol
- UUID/Password: $uuid
- Added: $(date)

## Usage
Import the config.json file to your client.

## Note
Keep this information secure.
README
    
    info "Subscription generated at: $SUBSCRIBE_DIR/$username/"
}

list_users() {
    local user_file="$WORK_DIR/users.json"
    if [[ -f "$user_file" ]]; then
        info "$INFO_USER_LIST"
        echo "=========================================="
        if command -v jq >/dev/null; then
            jq -r '.users[] | "User: \(.username)\nProtocol: \(.protocol)\nPort: \(.port)\nUUID: \(.uuid)\nAdded: \(.added)\n---"' "$user_file"
        else
            cat "$user_file"
        fi
    else
        echo "No users found"
    fi
}

generate_subscription_page() {
    local server_ip=$(curl -s "${GITHUB_PROXY_URL}https://${CDN_DOMAIN_SELECTED}" 2>/dev/null || echo "127.0.0.1")
    
    cat > "$SUBSCRIBE_DIR/index.html" << HTML
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>sing-box Subscription Service</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            max-width: 800px;
            margin: 0 auto;
            padding: 20px;
            background: #f5f5f5;
        }
        .container {
            background: white;
            padding: 30px;
            border-radius: 10px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
        }
        h1 {
            color: #333;
            border-bottom: 2px solid #4CAF50;
            padding-bottom: 10px;
        }
        .server-info {
            background: #e8f5e9;
            padding: 15px;
            border-radius: 5px;
            margin: 20px 0;
        }
        .protocols {
            display: grid;
            grid-template-columns: repeat(auto-fill, minmax(200px, 1fr));
            gap: 10px;
            margin: 20px 0;
        }
        .protocol {
            background: #2196F3;
            color: white;
            padding: 10px;
            border-radius: 5px;
            text-align: center;
        }
        .user-list {
            margin-top: 30px;
        }
        .user-item {
            background: #f8f9fa;
            padding: 10px;
            margin: 5px 0;
            border-left: 4px solid #4CAF50;
        }
        .footer {
            margin-top: 30px;
            text-align: center;
            color: #666;
            font-size: 0.9em;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>sing-box Subscription Service</h1>
        
        <div class="server-info">
            <h3>Server Information</h3>
            <p><strong>IP Address:</strong> $server_ip</p>
            <p><strong>Status:</strong> <span style="color: green;">● Online</span></p>
            <p><strong>Updated:</strong> $(date)</p>
        </div>
        
        <h3>Supported Protocols</h3>
        <div class="protocols">
HTML

    for protocol in "${PROTOCOL_LIST[@]}"; do
        echo "            <div class=\"protocol\">$protocol</div>" >> "$SUBSCRIBE_DIR/index.html"
    done

    cat >> "$SUBSCRIBE_DIR/index.html" << HTML
        </div>
        
        <h3>Connection Details</h3>
        <p>Default start port: $START_PORT_DEFAULT</p>
        <p>Total protocols: ${#PROTOCOL_LIST[@]}</p>
        
        <div class="footer">
            <p>Powered by sing-box v$SCRIPT_VERSION</p>
            <p>Auto-generated on $(date '+%Y-%m-%d %H:%M:%S')</p>
        </div>
    </div>
</body>
</html>
HTML
    
    info "$INFO_SUBSCRIBE"
    info "Access at: http://$server_ip:8080/subscribe/"
    info "Or direct file: $SUBSCRIBE_DIR/index.html"
}

backup_config() {
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_file="$BACKUP_DIR/config_$timestamp.tar.gz"
    
    step "$INFO_BACKUP"
    mkdir -p "$BACKUP_DIR"
    
    tar -czf "$backup_file" -C /etc "$SCRIPT_NAME" 2>/dev/null || \
    tar -czf "$backup_file" -C "$WORK_DIR" .
    
    info "Backup saved to: $backup_file"
    info "Size: $(du -h "$backup_file" | cut -f1)"
}

restore_config() {
    [[ ! -d "$BACKUP_DIR" ]] && error "Backup directory not found"
    
    echo "Available backups:"
    local backups=($(ls -1t "$BACKUP_DIR"/*.tar.gz 2>/dev/null))
    
    if [[ ${#backups[@]} -eq 0 ]]; then
        warn "No backup files found"
        return
    fi
    
    for i in "${!backups[@]}"; do
        echo "$((i+1))) $(basename "${backups[$i]}") ($(date -r "${backups[$i]}" '+%Y-%m-%d %H:%M:%S'))"
    done
    
    read -p "Select backup number: " choice
    local index=$((choice - 1))
    
    if [[ $index -lt 0 || $index -ge ${#backups[@]} ]]; then
        error "Invalid selection"
    fi
    
    local backup_file="${backups[$index]}"
    
    read -p "Restore $backup_file? (y/N): " confirm
    [[ "$confirm" != "y" ]] && return
    
    step "$INFO_RESTORE"
    systemctl stop "$SCRIPT_NAME"
    
    if tar -tzf "$backup_file" | grep -q "^$SCRIPT_NAME/"; then
        rm -rf "$WORK_DIR"
        tar -xzf "$backup_file" -C /etc
    else
        rm -rf "$WORK_DIR"
        mkdir -p "$WORK_DIR"
        tar -xzf "$backup_file" -C "$WORK_DIR"
    fi
    
    systemctl start "$SCRIPT_NAME"
    info "Config restored successfully"
}

update_singbox() {
    step "$INFO_UPDATE"
    
    # Test proxies first
    test_github_proxy
    
    local current_version=$("$BIN_FILE" version 2>/dev/null | head -1 | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+' || echo "unknown")
    local latest_version=$(get_latest_version)
    
    if [[ "$current_version" == "$latest_version" ]] || [[ "$current_version" == "unknown" && -n "$latest_version" ]]; then
        info "$INFO_NO_UPDATE"
        info "Current: $current_version"
        info "Latest: $latest_version"
        return
    fi
    
    info "Current version: $current_version"
    info "Latest version: $latest_version"
    
    read -p "Update to $latest_version? (y/N): " confirm
    [[ "$confirm" != "y" ]] && return
    
    systemctl stop "$SCRIPT_NAME"
    download_singbox "$latest_version"
    systemctl start "$SCRIPT_NAME"
    info "$INFO_UPDATED"
}

change_port() {
    local current_port=$(grep -o '"listen_port":[[:space:]]*[0-9]*' "$WORK_DIR/config.json" | grep -o '[0-9]*' | head -1)
    
    echo "Current port: ${current_port:-$START_PORT_DEFAULT}"
    read -p "Enter new port ($MIN_PORT-$MAX_PORT): " new_port
    new_port=${new_port:-$START_PORT_DEFAULT}
    
    if [[ "$new_port" =~ ^[0-9]+$ ]] && [ "$new_port" -ge "$MIN_PORT" ] && [ "$new_port" -le "$MAX_PORT" ]; then
        systemctl stop "$SCRIPT_NAME"
        sed -i "s/\"listen_port\":[[:space:]]*[0-9]*/\"listen_port\": $new_port/g" "$WORK_DIR/config.json"
        systemctl start "$SCRIPT_NAME"
        info "$INFO_PORT_CHANGE: $new_port"
    else
        error "Invalid port number. Must be between $MIN_PORT and $MAX_PORT"
    fi
}

show_stats() {
    if systemctl is-active "$SCRIPT_NAME" >/dev/null; then
        highlight "Service Statistics"
        echo "=========================="
        
        # Uptime
        local uptime=$(systemctl show -p ActiveEnterTimestamp "$SCRIPT_NAME" | cut -d= -f2)
        echo "Uptime: $uptime"
        
        # Memory usage
        local pid=$(systemctl show -p MainPID "$SCRIPT_NAME" | cut -d= -f2)
        if [[ "$pid" -ne 0 ]]; then
            local memory=$(ps -o rss= -p "$pid" 2>/dev/null | awk '{printf "%.1f MB", $1/1024}')
            local cpu=$(ps -o %cpu= -p "$pid" 2>/dev/null | awk '{printf "%.1f%%", $1}')
            echo "Memory: $memory"
            echo "CPU: $cpu"
        fi
        
        # Connection count
        local connections=$(ss -tn 2>/dev/null | grep -c ":$(grep -o '"listen_port":[[:space:]]*[0-9]*' "$WORK_DIR/config.json" | grep -o '[0-9]*')" || echo "0")
        echo "Active connections: $connections"
        
        # Config info
        local user_count=$(jq '.users | length' "$WORK_DIR/users.json" 2>/dev/null || echo "0")
        echo "User count: $user_count"
        
        # Ports in use
        echo "Ports configured:"
        for i in "${!PROTOCOLS[@]}"; do
            local port=$((START_PORT_DEFAULT + i))
            echo "  ${PROTOCOL_LIST[$i]}: $port"
        done
    else
        warn "Service not running"
    fi
}

port_hopping() {
    step "Setting up port hopping..."
    
    read -p "Enter base port [$MIN_HOPPING_PORT-$MAX_HOPPING_PORT]: " base_port
    base_port=${base_port:-$((MIN_HOPPING_PORT + RANDOM % 1000))}
    
    read -p "Enter number of hopping ports (2-100): " hop_count
    hop_count=${hop_count:-10}
    
    if [[ $hop_count -lt 2 || $hop_count -gt 100 ]]; then
        hop_count=10
        fi

    info "Setting up port hopping with $hop_count ports starting from $base_port"
    
    # Generate port hopping configuration
    cat > "$CONFIG_DIR/port_hopping.json" << HOPPING
{
  "port_hopping": {
    "enabled": true,
    "base_port": $base_port,
    "port_count": $hop_count,
    "change_interval": 300
  }
}
HOPPING
    
    info "Port hopping configuration saved to $CONFIG_DIR/port_hopping.json"
}

custom_port_config() {
    step "$INFO_CUSTOM_PORT"
    
    echo "Current protocol ports:"
    for i in "${!PROTOCOLS[@]}"; do
        local port=$((START_PORT_DEFAULT + i))
        echo "$((i+1)). ${PROTOCOL_LIST[$i]} - Port: $port"
    done
    
    read -p "Enter protocol number to modify (1-${#PROTOCOLS[@]}): " proto_num
    local index=$((proto_num - 1))
    
    if [[ $index -lt 0 || $index -ge ${#PROTOCOLS[@]} ]]; then
        error "Invalid protocol number"
    fi
    
    read -p "Enter new port for ${PROTOCOL_LIST[$index]} ($MIN_PORT-$MAX_PORT): " new_port
    
    if [[ "$new_port" =~ ^[0-9]+$ ]] && [ "$new_port" -ge "$MIN_PORT" ] && [ "$new_port" -le "$MAX_PORT" ]; then
        # Find and update the config file
        local protocol="${PROTOCOLS[$index]}"
        local old_config=$(find "$CONFIG_DIR" -name "*${protocol}*.json" | head -1)
        
        if [[ -f "$old_config" ]]; then
            systemctl stop "$SCRIPT_NAME"
            sed -i "s/\"listen_port\":[[:space:]]*[0-9]*/\"listen_port\": $new_port/g" "$old_config"
            info "Updated ${PROTOCOL_LIST[$index]} to port $new_port"
            systemctl start "$SCRIPT_NAME"
        else
            warn "Config file not found for ${protocol}, creating new one"
            generate_protocol_config "$protocol" "$new_port"
        fi
    else
        error "Invalid port number"
    fi
}

show_menu() {
    while true; do
        clear
        echo "╔═══════════════════════════════════════════╗"
        echo "║        sing-box Management Menu v$SCRIPT_VERSION    ║"
        echo "╠═══════════════════════════════════════════╣"
        echo "║ 1)  Install sing-box                      ║"
        echo "║ 2)  Start service                         ║"
        echo "║ 3)  Stop service                          ║"
        echo "║ 4)  Restart service                       ║"
        echo "║ 5)  Check status                          ║"
        echo "║ 6)  View logs                             ║"
        echo "║ 7)  Edit config                           ║"
        echo "║ 8)  Add user                              ║"
        echo "║ 9)  List users                            ║"
        echo "║ 10) Generate subscription                 ║"
        echo "║ 11) Update sing-box                       ║"
        echo "║ 12) Backup config                         ║"
        echo "║ 13) Restore config                        ║"
        echo "║ 14) Change main port                      ║"
        echo "║ 15) Custom port config                    ║"
        echo "║ 16) Port hopping setup                    ║"
        echo "║ 17) Show statistics                       ║"
        echo "║ 18) Test GitHub proxies                   ║"
        echo "║ 19) Test CDN domains                      ║"
        echo "║ 20) Setup multiple protocols              ║"
        echo "║ 21) Uninstall                             ║"
        echo "║ 0)  Exit                                  ║"
        echo "╚═══════════════════════════════════════════╝"
        
        echo -e "\nServer IP: $(curl -s ${GITHUB_PROXY_URL}https://${CDN_DOMAIN_SELECTED:-ip.sb} 2>/dev/null || echo 'Unknown')"
        echo -e "Protocols: ${#PROTOCOL_LIST[@]} available"
        
        read -p "Choice (0-21): " choice
        
        case $choice in
            1) install_singbox ;;
            2) systemctl start "$SCRIPT_NAME" && info "Service started" ;;
            3) systemctl stop "$SCRIPT_NAME" && info "Service stopped" ;;
            4) systemctl restart "$SCRIPT_NAME" && info "Service restarted" ;;
            5) systemctl status "$SCRIPT_NAME" --no-pager -l ;;
            6) tail -50 "$LOG_FILE" 2>/dev/null || echo "No log file" ;;
            7) ${EDITOR:-vi} "$WORK_DIR/config.json" ;;
            8) add_user ;;
            9) list_users ;;
            10) generate_subscription_page ;;
            11) update_singbox ;;
            12) backup_config ;;
            13) restore_config ;;
            14) change_port ;;
            15) custom_port_config ;;
            16) port_hopping ;;
            17) show_stats ;;
            18) test_github_proxy ;;
            19) test_cdn_domains ;;
            20) setup_multiple_protocols ;;
            21) uninstall_singbox ;;
            0) exit 0 ;;
            *) echo "Invalid choice" ;;
        esac
        
        read -p "Press Enter to continue..."
    done
}

install_singbox() {
    check_root
    check_system
    check_arch
    
    info "$INFO_START"
    
    # Test network connections
    test_github_proxy
    test_cdn_domains
    
    # Clean temp dir
    rm -rf "$TEMP_DIR"
    mkdir -p "$TEMP_DIR"
    
    # Install dependencies
    install_dependencies
    
    # Get latest version
    local version=$(get_latest_version)
    
    # Download and install
    download_singbox "$version"
    
    # Create directories
    create_directories
    
    # Setup multiple protocols
    setup_multiple_protocols
    
    # Create service
    create_service
    
    # Start service
    start_service
    
    # Check if running
    if check_service; then
        info "$INFO_SUCCESS"
        echo ""
        highlight "Installation Summary:"
        echo "========================="
        info "Version: $version"
        info "Config: $WORK_DIR/config.json"
        info "Logs: $LOG_FILE"
        info "Service: $SERVICE_FILE"
        info "Protocol ports: $START_PORT_DEFAULT - $((START_PORT_DEFAULT + ${#PROTOCOLS[@]} - 1))"
        info "Total protocols: ${#PROTOCOL_LIST[@]}"
        echo ""
        info "Status: systemctl status $SCRIPT_NAME"
        info "Manage: $0 menu"
        
        # Show server IP
        local server_ip=$(curl -s "${GITHUB_PROXY_URL}https://${CDN_DOMAIN_SELECTED}" 2>/dev/null || echo "Your_Server_IP")
        info "Server IP: $server_ip"
    else
        warn "$INFO_FAILED"
        journalctl -u "$SCRIPT_NAME" --no-pager -n 20
    fi
    
    # Cleanup
    rm -rf "$TEMP_DIR"
}

uninstall_singbox() {
    check_root
    
    echo -e "${RED}╔══════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║          WARNING: UNINSTALL sing-box          ║${NC}"
    echo -e "${RED}╠══════════════════════════════════════════════╣${NC}"
    echo -e "${RED}║ This will completely remove sing-box!        ║${NC}"
    echo -e "${RED}║ All configurations will be lost!             ║${NC}"
    echo -e "${RED}╚══════════════════════════════════════════════╝${NC}"
    
    read -p "Confirm uninstall? (yes/NO): " confirm
    
    if [[ "$confirm" != "yes" ]]; then
        info "Uninstall cancelled"
        return
    fi
    
    step "$INFO_UNINSTALL"
    
    # Stop and disable service
    systemctl stop "$SCRIPT_NAME" 2>/dev/null || true
    systemctl disable "$SCRIPT_NAME" 2>/dev/null || true
    
    # Remove files
    rm -f "$BIN_FILE"
    rm -f "$SERVICE_FILE"
    
    # Ask about config removal
    echo ""
    echo "What to do with configuration files?"
    echo "1) Delete everything"
    echo "2) Keep config files (recommended if reinstalling)"
    echo "3) Keep config and backup"
    read -p "Choice (1-3): " config_choice
    
    case $config_choice in
        1)
            rm -rf "$WORK_DIR"
            rm -f "$LOG_FILE"
            rm -rf "$BACKUP_DIR"
            info "All files deleted"
            ;;
        2)
            info "Config preserved at $WORK_DIR"
            ;;
        3)
            backup_config
            info "Config backed up and preserved"
            ;;
        *)
            info "Config preserved at $WORK_DIR"
            ;;
    esac
    
    # Remove temp files
    rm -rf "$TEMP_DIR"
    
    # Reload systemd
    systemctl daemon-reload
    
    info "✅ sing-box uninstalled"
    
    if [[ $config_choice -ne 1 ]]; then
        info "Note: Configuration files are still at:"
        [[ -d "$WORK_DIR" ]] && info "  $WORK_DIR"
        [[ -d "$BACKUP_DIR" ]] && info "  $BACKUP_DIR"
    fi
}

main() {
    # Set default values
    CDN_DOMAIN_SELECTED="ip.sb"
    GITHUB_PROXY_URL=""
    
    case "${1:-}" in
        install)
            install_singbox
            ;;
        uninstall)
            uninstall_singbox
            ;;
        start)
            systemctl start "$SCRIPT_NAME"
            info "Service started"
            ;;
        stop)
            systemctl stop "$SCRIPT_NAME"
            info "Service stopped"
            ;;
        restart)
            systemctl restart "$SCRIPT_NAME"
            info "Service restarted"
            ;;
        status)
            systemctl status "$SCRIPT_NAME" --no-pager -l
            ;;
        log)
            if [[ -f "$LOG_FILE" ]]; then
                tail -100 "$LOG_FILE"
            else
                journalctl -u "$SCRIPT_NAME" --no-pager -n 50
            fi
            ;;
        config)
            ${EDITOR:-vi} "$WORK_DIR/config.json"
            ;;
        add-user|adduser)
            add_user
            ;;
        list-users|listusers)
            list_users
            ;;
        subscribe|sub)
            generate_subscription_page
            ;;
        update|upgrade)
            update_singbox
            ;;
        backup)
            backup_config
            ;;
        restore)
            restore_config
            ;;
        port)
            change_port
            ;;
        custom-port)
            custom_port_config
            ;;
        port-hop|hopping)
            port_hopping
            ;;
        stats|stat)
            show_stats
            ;;
        test-proxy)
            test_github_proxy
            ;;
        test-cdn)
            test_cdn_domains
            ;;
        setup|setup-protocols)
            setup_multiple_protocols
            ;;
        menu|m)
            show_menu
            ;;
        --help|-h|help)
            echo "Usage: $0 [command]"
            echo ""
            echo "Available commands:"
            echo "  install           Install sing-box"
            echo "  uninstall         Uninstall completely"
            echo "  start             Start service"
            echo "  stop              Stop service"
            echo "  restart           Restart service"
            echo "  status            Check service status"
            echo "  log               View logs"
            echo "  config            Edit configuration"
            echo "  add-user          Add new user"
            echo "  list-users        List all users"
            echo "  subscribe         Generate subscription page"
            echo "  update            Update to latest version"
            echo "  backup            Backup configuration"
            echo "  restore           Restore from backup"
            echo "  port              Change main port"
            echo "  custom-port       Custom port configuration"
            echo "  port-hop          Setup port hopping"
            echo "  stats             Show service statistics"
            echo "  test-proxy        Test GitHub proxies"
            echo "  test-cdn          Test CDN domains"
            echo "  setup             Setup multiple protocols"
            echo "  menu              Interactive menu"
            echo "  --help, -h        Show this help"
            echo "  --version, -v     Show version"
            echo ""
            echo "Examples:"
            echo "  $0 install        # Install sing-box"
            echo "  $0 menu           # Interactive menu"
            echo "  $0 add-user       # Add a new user"
            echo "  $0 update         # Update to latest version"
            ;;
        --version|-v|version)
            echo "sing-box Management Script"
            echo "Version: $SCRIPT_VERSION"
            echo "Protocols supported: ${#PROTOCOL_LIST[@]}"
            echo "Default start port: $START_PORT_DEFAULT"
            echo "GitHub proxies: ${#GITHUB_PROXY[@]}"
            echo "CDN domains: ${#CDN_DOMAIN[@]}"
            ;;
        *)
            if [[ -z "$1" ]]; then
                show_menu
            else
                error "Unknown command: $1"
                echo "Use '$0 --help' for available commands"
            fi
            ;;
    esac
}

# Run main function
main "$@"
   
