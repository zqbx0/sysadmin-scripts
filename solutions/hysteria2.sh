#!/usr/bin/env bash
# -*- coding: utf-8 -*-
# Hysteria2 终极部署脚本
# 结合：企业级稳定性 + 用户友好界面 + 完整功能
# 支持：命令行参数、环境变量、自动备份、端口检测、二维码生成

set -euo pipefail  # 严格错误处理

# ========== 全局配置 ==========
HYSTERIA_VERSION="${HYSTERIA_VERSION:-v1.0.1}"
DEFAULT_PORT="${DEFAULT_PORT:-$(shuf -i 10000-65535 -n 1)}"
AUTH_PASSWORD="${AUTH_PASSWORD:-$(openssl rand -base64 12 | tr -d '/+=' | cut -c1-20)}"
CERT_FILE="${CERT_FILE:-cert.pem}"
KEY_FILE="${KEY_FILE:-key.pem}"
SNI="${SNI:-cloudflare.com}"
ALPN="${ALPN:-h3}"
CONFIG_FILE="${CONFIG_FILE:-server.yaml}"
BACKUP_DIR="${BACKUP_DIR:-./backups}"
LOG_FILE="${LOG_FILE:-./hysteria_install.log}"

# ========== 颜色定义 ==========
# 基础颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

# 背景色（用于美观显示）
BG_BLUE='\033[44m\033[37m'
BG_GREEN='\033[42m\033[30m'
BG_YELLOW='\033[43m\033{30m'

# ========== 输出函数 ==========
print_banner() {
    clear
    echo -e "${BG_BLUE}══════════════════════════════════════════════════════════${NC}"
    echo -e "${BG_BLUE}                  Hysteria2 终极部署脚本                  ${NC}"
    echo -e "${BG_BLUE}             企业级稳定性 + 用户友好界面                 ${NC}"
    echo -e "${BG_BLUE}══════════════════════════════════════════════════════════${NC}"
    echo ""
}

print_section() {
    local title="$1"
    echo ""
    echo -e "${CYAN}▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬${NC}"
    echo -e "${WHITE}  $title ${NC}"
    echo -e "${CYAN}▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬${NC}"
}

log_info() { 
    echo -e "${BLUE}[ℹ]${NC} $*" | tee -a "$LOG_FILE"
}

log_success() { 
    echo -e "${GREEN}[✓]${NC} $*" | tee -a "$LOG_FILE"
}

log_warn() { 
    echo -e "${YELLOW}[⚠]${NC} $*" | tee -a "$LOG_FILE"
}

log_error() { 
    echo -e "${RED}[✗]${NC} $*" | tee -a "$LOG_FILE" >&2
}

print_step() {
    echo -e "${PURPLE}▶${NC} $*"
}

# ========== 帮助信息 ==========
show_help() {
    cat << EOF
${GREEN}用法: $0 [选项] [端口]${NC}

${WHITE}Hysteria2 终极部署脚本 - 结合稳定性和用户体验${NC}

${YELLOW}选项:${NC}
  -p, --port PORT         指定服务器端口 (默认: 随机端口)
  -w, --password PASS     设置认证密码 (默认: 随机生成)
  -s, --sni SNI           设置SNI域名 (默认: cloudflare.com)
  -a, --alpn ALPN         设置ALPN协议 (默认: h3)
  -c, --config FILE       指定配置文件路径
  --skip-download         跳过二进制下载（使用现有）
  --skip-cert             跳过证书生成（使用现有）
  --no-backup             跳过备份
  --no-color              禁用彩色输出
  --no-qrcode             不生成二维码
  -h, --help              显示此帮助信息

${YELLOW}示例:${NC}
  $0 443                    # 使用端口443
  $0 -p 8443 -w MyPass123  # 指定端口和密码
  $0 --skip-cert           # 使用现有证书
  SERVER_PORT=8443 $0      # 使用环境变量

${YELLOW}优先级:${NC} 命令行参数 > 环境变量 > 默认值

${YELLOW}功能特色:${NC}
  ✓ 企业级稳定性 (错误处理、备份、重试)
  ✓ 美观的用户界面 (彩色输出、二维码)
  ✓ 完整的客户端配置生成
  ✓ 端口占用检测和安全验证
  ✓ 详细的安装日志记录
EOF
    exit 0
}

# ========== 参数解析 ==========
parse_args() {
    # 默认值
    SKIP_DOWNLOAD=false
    SKIP_CERT=false
    NO_BACKUP=false
    NO_COLOR=false
    NO_QRCODE=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -p|--port)
                SERVER_PORT="$2"
                shift 2
                ;;
            -w|--password)
                AUTH_PASSWORD="$2"
                shift 2
                ;;
            -s|--sni)
                SNI="$2"
                shift 2
                ;;
            -a|--alpn)
                ALPN="$2"
                shift 2
                ;;
            -c|--config)
                CONFIG_FILE="$2"
                shift 2
                ;;
            --skip-download)
                SKIP_DOWNLOAD=true
                shift
                ;;
            --skip-cert)
                SKIP_CERT=true
                shift
                ;;
            --no-backup)
                NO_BACKUP=true
                shift
                ;;
            --no-color)
                NO_COLOR=true
                shift
                ;;
            --no-qrcode)
                NO_QRCODE=true
                shift
                ;;
            -h|--help)
                show_help
                ;;
            --)
                shift
                break
                ;;
            -*)
                log_error "未知选项: $1"
                show_help
                ;;
            *)
                if [[ $1 =~ ^[0-9]+$ ]]; then
                    SERVER_PORT="$1"
                else
                    log_error "无效的端口: $1"
                    exit 1
                fi
                shift
                ;;
        esac
    done
    
    # 应用无颜色选项
    if [ "$NO_COLOR" = true ]; then
        RED=''; GREEN=''; YELLOW=''; BLUE=''; PURPLE=''; CYAN=''; WHITE=''
        BG_BLUE=''; BG_GREEN=''; BG_YELLOW=''; NC=''
    fi
}

# ========== 端口检查 ==========
check_port() {
    local port="$1"
    
    print_step "检查端口配置..."
    
    # 1. 基本验证
    if ! [[ "$port" =~ ^[0-9]+$ ]] || [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
        log_error "端口号必须为 1-65535 之间的数字"
        return 1
    fi
    
    # 2. 特权端口警告
    if [ "$port" -lt 1024 ] && [ "$EUID" -ne 0 ]; then
        log_warn "端口 $port 是特权端口 (<1024)，建议使用root权限运行"
        echo -e "${YELLOW}提示: 或者使用 1024-65535 之间的端口${NC}"
    fi
    
    # 3. 检查端口占用
    log_info "检查端口 $port 是否被占用..."
    
    local occupied=false
    local process_info=""
    
    # 使用 ss 检查
    if command -v ss &>/dev/null; then
        if ss -tuln | grep -q ":$port "; then
            occupied=true
            process_info=$(ss -tulpn | grep ":$port " | head -1)
        fi
    # 使用 netstat 检查
    elif command -v netstat &>/dev/null; then
        if netstat -tuln 2>/dev/null | grep -q ":$port "; then
            occupied=true
            process_info=$(netstat -tulpn 2>/dev/null | grep ":$port " | head -1)
        fi
    else
        log_warn "无法检测端口占用情况（未安装 ss 或 netstat）"
    fi
    
    # 4. 处理端口占用
    if [ "$occupied" = true ]; then
        log_error "端口 $port 已被占用！"
        echo -e "${RED}占用信息:${NC} $process_info"
        
        # 交互式询问
        if [ -t 0 ]; then  # 检查是否在终端中运行
            read -p "是否强制使用此端口？(y/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                log_error "安装中止"
                exit 1
            else
                log_warn "警告：端口冲突可能导致服务启动失败"
            fi
        else
            log_error "非交互模式，安装中止"
            exit 1
        fi
    else
        log_success "端口 $port 可用"
    fi
    
    return 0
}

# ========== 系统架构检测 ==========
get_architecture() {
    local machine
    machine=$(uname -m | tr '[:upper:]' '[:lower:]')
    
    case "$machine" in
        x86_64|amd64)
            echo "amd64"
            ;;
        aarch64|arm64|armv8l)
            echo "arm64"
            ;;
        armv7l|armhf)
            echo "armv7"
            ;;
        i386|i686)
            echo "386"
            ;;
        *)
            log_error "不支持的架构: $machine"
            exit 1
            ;;
    esac
}

# ========== 备份现有配置 ==========
backup_existing() {
    [ "$NO_BACKUP" = true ] && return 0
    
    print_step "备份现有配置文件..."
    
    mkdir -p "$BACKUP_DIR"
    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    
    local backup_count=0
    local files_to_backup=("$CONFIG_FILE" "cert.pem" "key.pem" "clash.yaml" "singbox.json" "client.json" "client-info.txt")
    
    for file in "${files_to_backup[@]}"; do
        if [ -f "$file" ]; then
            cp "$file" "${BACKUP_DIR}/${file}.${timestamp}.bak" 2>/dev/null || true
            ((backup_count++))
        fi
    done
    
    if [ $backup_count -gt 0 ]; then
        log_success "已备份 $backup_count 个文件到 $BACKUP_DIR"
    else
        log_info "没有需要备份的现有文件"
    fi
}

# ========== 下载二进制文件 ==========
download_binary() {
    local arch="$1"
    local bin_name="hysteria-linux-${arch}"
    local bin_path="./${bin_name}"
    
    # 跳过下载检查
    if [ "$SKIP_DOWNLOAD" = true ] && [ -f "$bin_path" ]; then
        log_info "跳过二进制下载（使用现有文件）"
        chmod +x "$bin_path" 2>/dev/null || true
        return 0
    fi
    
    # 检查现有文件
    if [ -f "$bin_path" ]; then
        log_info "二进制文件已存在: $bin_path"
        chmod +x "$bin_path"
        return 0
    fi
    
    print_step "下载 Hysteria2 二进制文件..."
    
    local url="https://github.com/apernet/hysteria/releases/download/app/${HYSTERIA_VERSION}/${bin_name}"
    local alt_url="https://ghproxy.com/https://github.com/apernet/hysteria/releases/download/app/${HYSTERIA_VERSION}/${bin_name}"
    
    # 下载并重试
    local download_success=false
    for attempt in {1..3}; do
        log_info "尝试下载 (第 $attempt 次): $url"
        
        if curl -L --retry 3 --connect-timeout 30 --max-time 120 \
            -o "$bin_path" "$url" 2>>"$LOG_FILE"; then
            download_success=true
            break
        fi
        
        log_warn "下载失败，2秒后重试..."
        sleep 2
    done
    
    # 尝试备用源
    if [ "$download_success" = false ]; then
        log_info "尝试备用下载源: $alt_url"
        if curl -L --connect-timeout 30 -o "$bin_path" "$alt_url" 2>>"$LOG_FILE"; then
            download_success=true
            log_success "从备用源下载成功"
        fi
    fi
    
    # 最终检查
    if [ "$download_success" = false ] || [ ! -f "$bin_path" ]; then
        log_error "二进制文件下载失败"
        log_error "请检查："
        log_error "1. 网络连接"
        log_error "2. 版本号是否存在: $HYSTERIA_VERSION"
        log_error "3. 架构是否支持: $arch"
        rm -f "$bin_path" 2>/dev/null || true
        exit 1
    fi
    
    chmod +x "$bin_path"
    
    # 验证文件
    if [ -x "$bin_path" ]; then
        log_success "下载完成: $bin_path"
        
        # 显示版本信息
        local version_info
        if version_info=$("$bin_path" version 2>/dev/null); then
            log_info "版本信息: $version_info"
        fi
    else
        log_error "文件校验失败"
        exit 1
    fi
}

# ========== 生成证书 ==========
generate_certificate() {
    print_step "生成TLS证书..."
    
    # 跳过证书检查
    if [ "$SKIP_CERT" = true ] && [ -f "$CERT_FILE" ] && [ -f "$KEY_FILE" ]; then
        log_info "跳过证书生成（使用现有证书）"
        return 0
    fi
    
    # 使用现有证书
    if [ -f "$CERT_FILE" ] && [ -f "$KEY_FILE" ]; then
        log_info "使用现有证书: $CERT_FILE, $KEY_FILE"
        return 0
    fi
    
    # 检查 openssl
    if ! command -v openssl &>/dev/null; then
        log_error "需要 openssl，请先安装:"
        log_error "  Ubuntu/Debian: apt install openssl"
        log_error "  CentOS/RHEL: yum install openssl"
        log_error "  Alpine: apk add openssl"
        exit 1
    fi
    
    # 生成 ECC 密钥
    log_info "生成 ECC 密钥..."
    if ! openssl ecparam -genkey -name prime256v1 -out "$KEY_FILE" 2>/dev/null && \
       ! openssl genpkey -algorithm EC -pkeyopt ec_paramgen_curve:P-256 -out "$KEY_FILE" 2>/dev/null; then
        log_warn "ECC密钥生成失败，使用RSA密钥"
        openssl genrsa -out "$KEY_FILE" 2048 2>/dev/null
    fi
    
    # 生成证书
    log_info "生成自签证书..."
    if openssl req -new -x509 -days 3650 -key "$KEY_FILE" \
        -out "$CERT_FILE" -subj "/CN=${SNI}" \
        -addext "subjectAltName=DNS:${SNI}" 2>/dev/null || \
       openssl req -new -x509 -days 3650 -key "$KEY_FILE" \
        -out "$CERT_FILE" -subj "/CN=${SNI}" 2>/dev/null; then
        
        log_success "证书生成成功"
        
        # 显示证书信息
        if openssl x509 -in "$CERT_FILE" -noout -text 2>/dev/null | grep -q "Subject:"; then
            log_info "证书信息:"
            openssl x509 -in "$CERT_FILE" -noout -subject -dates 2>/dev/null | while read -r line; do
                log_info "  $line"
            done
        fi
    else
        log_error "证书生成失败"
        exit 1
    fi
}

# ========== 生成配置文件 ==========
create_config() {
    print_step "生成服务器配置文件..."
    
    cat > "$CONFIG_FILE" <<EOF
listen: ":${SERVER_PORT}"
tls:
  cert: "$(realpath "$CERT_FILE" 2>/dev/null || echo "$CERT_FILE")"
  key: "$(realpath "$KEY_FILE" 2>/dev/null || echo "$KEY_FILE")"
  sni: "${SNI}"
  alpn:
    - "${ALPN}"
auth:
  type: "password"
  password: "${AUTH_PASSWORD}"
bandwidth:
  up: "500 mbps"
  down: "500 mbps"
quic:
  initStreamReceiveWindow: 8388608
  maxStreamReceiveWindow: 8388608
  initConnReceiveWindow: 20971520
  maxConnReceiveWindow: 20971520
  maxIdleTimeout: 30s
  keepAlivePeriod: 10s
  disablePathMTUDiscovery: false
ignoreClientBandwidth: false
disableUDP: false
udpIdleTimeout: 60s
resolver:
  type: "udp"
  tcp:
    addr: "8.8.8.8:53"
    timeout: 4s
  udp:
    addr: "8.8.8.8:53"
    timeout: 4s
  tls:
    addr: "1.1.1.1:853"
    timeout: 10s
    sni: "cloudflare-dns.com"
    insecure: false
  https:
    addr: "https://1.1.1.1/dns-query"
    timeout: 10s
EOF
    
    if [ -f "$CONFIG_FILE" ]; then
        log_success "配置文件已生成: $CONFIG_FILE"
        log_info "配置摘要:"
        log_info "  - 监听端口: ${SERVER_PORT}"
        log_info "  - 认证密码: ${AUTH_PASSWORD:0:8}****"
        log_info "  - TLS SNI: ${SNI}"
        log_info "  - ALPN: ${ALPN}"
    else
        log_error "配置文件生成失败"
        exit 1
    fi
}

# ========== 获取服务器IP ==========
get_server_ip() {
    print_step "获取服务器公网IP..."
    
    local ip_services=(
        "https://api.ipify.org"
        "https://ipv4.icanhazip.com"
        "https://checkip.amazonaws.com"
        "https://ifconfig.me/ip"
        "https://api.my-ip.io/ip"
    )
    
    local server_ip=""
    
    for service in "${ip_services[@]}"; do
        log_info "尝试从 $service 获取IP..."
        
        # 使用 curl 获取，带超时
        if ip=$(curl -s --max-time 5 "$service" 2>/dev/null | grep -oE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}'); then
            if [ -n "$ip" ]; then
                server_ip="$ip"
                log_success "获取到服务器IP: $server_ip"
                
                # 验证IP格式
                if [[ $server_ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                    echo "$server_ip"
                    return 0
                fi
            fi
        fi
        sleep 0.5
    done
    
    # 如果所有服务都失败
    log_warn "无法自动获取公网IP"
    
    if [ -t 0 ]; then  # 交互模式
        read -p "请输入服务器公网IP地址: " -r server_ip
        if [[ $server_ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            echo "$server_ip"
            return 0
        else
            log_error "无效的IP地址格式"
            echo "YOUR_SERVER_IP"
            return 1
        fi
    else
        log_warn "使用占位符 IP，请手动修改配置文件"
        echo "YOUR_SERVER_IP"
        return 1
    fi
}

# ========== 生成客户端配置 ==========
generate_client_configs() {
    local server_ip="$1"
    local config_name="HY2-$(date +%m%d%H%M)"
    
    print_step "生成客户端配置文件..."
    
    # 1. Hysteria2 标准链接
    local hysteria_link="hysteria2://${AUTH_PASSWORD}@${server_ip}:${SERVER_PORT}/?sni=${SNI}&alpn=${ALPN}&insecure=1#${config_name}"
    
    # 2. 通用信息文件
    cat > client-info.txt <<EOF
$(date '+%Y-%m-%d %H:%M:%S')
══════════════════════════════════════════════
              Hysteria2 节点配置
══════════════════════════════════════════════

【服务器信息】
├ 地址: ${server_ip}
├ 端口: ${SERVER_PORT}
├ 密码: ${AUTH_PASSWORD}
├ SNI: ${SNI}
├ ALPN: ${ALPN}
└ 跳过证书验证: 是

【订阅链接】
${hysteria_link}

【Clash Meta 配置】
proxies:
  - name: "${config_name}"
    type: hysteria2
    server: ${server_ip}
    port: ${SERVER_PORT}
    password: ${AUTH_PASSWORD}
    sni: ${SNI}
    alpn: ["${ALPN}"]
    skip-cert-verify: true
    up: "500 Mbps"
    down: "500 Mbps"

【v2rayN 配置】
地址: ${server_ip}
端口: ${SERVER_PORT}
用户密码: ${AUTH_PASSWORD}
SNI: ${SNI}
ALPN: ${ALPN}
允许不安全连接: true

【测试命令】
curl --http3 -vk "https://${server_ip}:${SERVER_PORT}/"
EOF
    
    # 3. Clash 配置文件
    cat > clash.yaml <<EOF
mixed-port: 7890
allow-lan: false
mode: rule
log-level: info
external-controller: 127.0.0.1:9090
dns:
  enable: true
  listen: 0.0.0.0:53
  enhanced-mode: fake-ip
  nameserver:
    - 8.8.8.8
    - 1.1.1.1

proxies:
  - name: "${config_name}"
    type: hysteria2
    server: ${server_ip}
    port: ${SERVER_PORT}
    password: ${AUTH_PASSWORD}
    sni: ${SNI}
    alpn: 
      - ${ALPN}
    skip-cert-verify: true
    up: "500 Mbps"
    down: "500 Mbps"

proxy-groups:
  - name: 🚀 节点选择
    type: select
    proxies:
      - ${config_name}
      - DIRECT

rules:
  - MATCH,🚀 节点选择
EOF
    
    # 4. Sing-box 配置
    cat > singbox.json <<EOF
{
  "log": {
    "level": "info"
  },
  "dns": {
    "servers": [
      {
        "tag": "google",
        "address": "8.8.8.8"
      }
    ]
  },
  "inbounds": [
    {
      "type": "mixed",
      "tag": "mixed-in",
      "listen": "127.0.0.1",
      "listen_port": 1080
    }
  ],
  "outbounds": [
    {
      "type": "direct",
      "tag": "direct"
    },
    {
      "type": "hysteria2",
      "tag": "${config_name}",
      "server": "${server_ip}",
      "server_port": ${SERVER_PORT},
      "password": "${AUTH_PASSWORD}",
      "tls": {
        "enabled": true,
        "server_name": "${SNI}",
        "alpn": ["${ALPN}"],
        "insecure": true
      }
    }
  ],
  "route": {
    "rules": [
      {
        "outbound": "${config_name}",
        "geoip": ["private"]
      }
    ]
  }
}
EOF
    
    # 5. v2rayN 配置
    cat > v2rayn.json <<EOF
{
  "version": "2",
  "remarks": "${config_name}",
  "address": "${server_ip}",
  "port": ${SERVER_PORT},
  "id": "${AUTH_PASSWORD}",
  "security": "auto",
  "network": "tcp",
  "headerType": "none",
  "host": "",
  "path": "",
  "streamSecurity": "tls",
  "allowInsecure": true,
  "serverName": "${SNI}",
  "alpn": "${ALPN}",
  "type": "hysteria2",
  "sni": "${SNI}"
}
EOF
    
    log_success "已生成 4 种客户端配置文件"
}

# ========== 显示二维码 ==========
show_qrcode() {
    [ "$NO_QRCODE" = true ] && return 0
    
    local server_ip="$1"
    local hysteria_link="hysteria2://${AUTH_PASSWORD}@${server_ip}:${SERVER_PORT}/?sni=${SNI}&alpn=${ALPN}&insecure=1#HY2-Node"
    
    print_step "生成节点二维码..."
    
    # 检查二维码工具
    if command -v qrencode &>/dev/null; then
        echo ""
        echo -e "${BG_YELLOW}══════════════════════════════════════════════════════════${NC}"
        echo -e "${WHITE}                    📱 节点二维码                        ${NC}"
        echo -e "${BG_YELLOW}══════════════════════════════════════════════════════════${NC}"
        echo ""
        echo "$hysteria_link" | qrencode -t UTF8
        echo ""
        echo -e "${YELLOW}提示: 使用手机扫描二维码快速添加节点${NC}"
        echo -e "${BG_YELLOW}══════════════════════════════════════════════════════════${NC}"
        echo ""
    elif command -v qrcode-terminal &>/dev/null; then
        echo "$hysteria_link" | qrcode-terminal
    else
        log_info "未安装二维码工具，跳过二维码生成"
        log_info "安装建议:"
        log_info "  Ubuntu/Debian: apt install qrencode"
        log_info "  CentOS/RHEL: yum install qrencode"
        log_info "  Alpine: apk add qrencode"
    fi
}

# ========== 美观显示节点信息 ==========
show_node_info() {
    local server_ip="$1"
    local config_name="HY2-$(date +%m%d%H%M)"
    local hysteria_link="hysteria2://${AUTH_PASSWORD}@${server_ip}:${SERVER_PORT}/?sni=${SNI}&alpn=${ALPN}&insecure=1#${config_name}"
    
    print_section "🎉 部署完成！节点信息如下"
    
    echo -e "${BG_GREEN}══════════════════════════════════════════════════════════${NC}"
    echo -e "${WHITE}                🚀 Hysteria2 节点配置                     ${NC}"
    echo -e "${BG_GREEN}══════════════════════════════════════════════════════════${NC}"
    echo ""
    
    # 服务器信息表格
    echo -e "${YELLOW}📊 服务器信息${NC}"
    echo -e "${WHITE}├────────────────────────────────────────────${NC}"
    echo -e "  ${CYAN}🌐 地址${NC}: ${GREEN}$server_ip${NC}"
    echo -e "  ${CYAN}🔌 端口${NC}: ${GREEN}$SERVER_PORT${NC}"
    echo -e "  ${CYAN}🔑 密码${NC}: ${GREEN}$AUTH_PASSWORD${NC}"
    echo -e "  ${CYAN}📍 SNI${NC}: ${GREEN}$SNI${NC}"
    echo -e "  ${CYAN}🔗 ALPN${NC}: ${GREEN}$ALPN${NC}"
    echo -e "${WHITE}└────────────────────────────────────────────${NC}"
    echo ""
    
    # 订阅链接（突出显示）
    echo -e "${YELLOW}📱 订阅链接（复制使用）${NC}"
    echo -e "${WHITE}┌────────────────────────────────────────────${NC}"
    echo -e "${GREEN}$hysteria_link${NC}"
    echo -e "${WHITE}└────────────────────────────────────────────${NC}"
    echo ""
    
    # 配置文件列表
    echo -e "${YELLOW}📁 生成的文件${NC}"
    echo -e "${WHITE}├────────────────────────────────────────────${NC}"
    local files_generated=0
    for file in "$CONFIG_FILE" "cert.pem" "key.pem" "client-info.txt" "clash.yaml" "singbox.json" "v2rayn.json"; do
        if [ -f "$file" ]; then
            echo -e "  📄 ${file}"
            ((files_generated++))
        fi
    done
    echo -e "${WHITE}└────────────────────────────────────────────${NC}"
    echo -e "  共生成 ${GREEN}$files_generated${NC} 个文件"
    echo ""
    
    # 测试命令
    echo -e "${YELLOW}🔧 快速测试${NC}"
    echo -e "${WHITE}┌────────────────────────────────────────────${NC}"
    echo -e "  ${CYAN}测试连接${NC}:"
    echo -e "  ${GREEN}curl --http3 -vk https://${server_ip}:${SERVER_PORT}/${NC}"
    echo -e "${WHITE}└────────────────────────────────────────────${NC}"
    echo ""
    
    # 启动命令
    echo -e "${YELLOW}🚀 启动服务${NC}"
    echo -e "${WHITE}┌────────────────────────────────────────────${NC}"
    echo -e "  ${CYAN}前台运行${NC}:"
    echo -e "  ${GREEN}./hysteria-linux-${ARCH} server -c ${CONFIG_FILE}${NC}"
    echo -e ""
    echo -e "  ${CYAN}后台运行${NC}:"
    echo -e "  ${GREEN}nohup ./hysteria-linux-${ARCH} server -c ${CONFIG_FILE} > hysteria.log 2>&1 &${NC}"
    echo -e "${WHITE}└────────────────────────────────────────────${NC}"
    echo ""
    
    echo -e "${BG_GREEN}══════════════════════════════════════════════════════════${NC}"
    echo -e "${WHITE}         💡 配置已保存到 client-info.txt 文件          ${NC}"
    echo -e "${BG_GREEN}══════════════════════════════════════════════════════════${NC}"
}

# ========== 显示启动指导 ==========
show_startup_guide() {
    local server_ip="$1"
    
    print_section "🔧 服务管理指南"
    
    echo -e "${YELLOW}📋 常用命令${NC}"
    echo -e "${WHITE}├────────────────────────────────────────────${NC}"
    echo -e "  ${CYAN}启动服务${NC}: ${GREEN}./hysteria-linux-${ARCH} server -c ${CONFIG_FILE}${NC}"
    echo -e "  ${CYAN}后台运行${NC}: ${GREEN}nohup ./hysteria-linux-${ARCH} server -c ${CONFIG_FILE} &${NC}"
    echo -e "  ${CYAN}查看日志${NC}: ${GREEN}tail -f hysteria.log${NC}"
    echo -e "  ${CYAN}停止服务${NC}: ${GREEN}pkill -f hysteria${NC}"
    echo -e "  ${CYAN}检查状态${NC}: ${GREEN}ps aux | grep hysteria${NC}"
    echo -e "${WHITE}└────────────────────────────────────────────${NC}"
    echo ""
    
    echo -e "${YELLOW}⚡ 系统服务配置（Systemd）${NC}"
    echo -e "${WHITE}├────────────────────────────────────────────${NC}"
    cat << EOF
  # 创建系统服务
  sudo tee /etc/systemd/system/hysteria2.service <<-'EOF_SERVICE'
[Unit]
Description=Hysteria2 Proxy Server
After=network.target

[Service]
Type=simple
User=$(whoami)
WorkingDirectory=$(pwd)
ExecStart=$(pwd)/hysteria-linux-${ARCH} server -c $(pwd)/${CONFIG_FILE}
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF_SERVICE

  # 启动服务
  sudo systemctl daemon-reload
  sudo systemctl enable hysteria2
  sudo systemctl start hysteria2
  sudo systemctl status hysteria2
EOF
    echo -e "${WHITE}└────────────────────────────────────────────${NC}"
    echo ""
    
    # 防火墙提示
    echo -e "${YELLOW}🔥 防火墙配置${NC}"
    echo -e "${WHITE}├────────────────────────────────────────────${NC}"
    echo -e "  ${RED}重要: 确保防火墙已开放端口 ${SERVER_PORT}${NC}"
    echo -e ""
    echo -e "  ${CYAN}UFW (Ubuntu)${NC}:"
    echo -e "    sudo ufw allow ${SERVER_PORT}/tcp"
    echo -e "    sudo ufw allow ${SERVER_PORT}/udp"
    echo -e ""
    echo -e "  ${CYAN}Firewalld (CentOS)${NC}:"
    echo -e "    sudo firewall-cmd --permanent --add-port=${SERVER_PORT}/tcp"
    echo -e "    sudo firewall-cmd --permanent --add-port=${SERVER_PORT}/udp"
    echo -e "    sudo firewall-cmd --reload"
    echo -e "${WHITE}└────────────────────────────────────────────${NC}"
}

# ========== 保存安装记录 ==========
save_installation_record() {
    local server_ip="$1"
    local arch="$2"
    
    print_step "保存安装记录..."
    
    cat > install-record.json <<EOF
{
  "installation": {
    "timestamp": "$(date -Iseconds)",
    "script_version": "ultimate-v1.0",
    "hysteria_version": "${HYSTERIA_VERSION}"
  },
  "server": {
    "ip": "${server_ip}",
    "port": ${SERVER_PORT},
    "architecture": "${arch}"
  },
  "security": {
    "password": "${AUTH_PASSWORD}",
    "sni": "${SNI}",
    "alpn": "${ALPN}",
    "cert_file": "${CERT_FILE}",
    "key_file": "${KEY_FILE}"
  },
  "config": {
    "config_file": "${CONFIG_FILE}",
    "log_file": "${LOG_FILE}",
    "backup_dir": "${BACKUP_DIR}"
  },
  "files_generated": [
    "server.yaml",
    "cert.pem",
    "key.pem",
    "client-info.txt",
    "clash.yaml",
    "singbox.json",
    "v2rayn.json",
    "install-record.json"
  ]
}
EOF
    
    if [ -f "install-record.json" ]; then
        log_success "安装记录已保存: install-record.json"
    fi
}

# ========== 询问是否启动服务 ==========
ask_to_start_service() {
    local arch="$1"
    
    print_section "⚡ 服务启动选项"
    
    if [ -t 0 ]; then  # 交互模式
        echo -e "${YELLOW}是否立即启动 Hysteria2 服务？${NC}"
        echo ""
        echo -e "${CYAN}1) 前台运行（调试用）${NC}"
        echo -e "${CYAN}2) 后台运行（推荐）${NC}"
        echo -e "${CYAN}3) 创建系统服务（Systemd）${NC}"
        echo -e "${CYAN}4) 手动启动（稍后自行启动）${NC}"
        echo ""
        
        read -p "请选择 (1-4，默认: 2): " -r choice
        choice=${choice:-2}
        
        case $choice in
            1)
                log_info "前台启动服务..."
                echo -e "${GREEN}启动命令: ./hysteria-linux-${arch} server -c ${CONFIG_FILE}${NC}"
                echo ""
                ./hysteria-linux-${arch} server -c "$CONFIG_FILE"
                ;;
            2)
                log_info "后台启动服务..."
                nohup ./hysteria-linux-${arch} server -c "$CONFIG_FILE" > hysteria.log 2>&1 &
                local pid=$!
                sleep 2
                if ps -p $pid > /dev/null; then
                    log_success "服务已后台启动 (PID: $pid)"
                    log_info "查看日志: tail -f hysteria.log"
                    log_info "停止服务: kill $pid"
                else
                    log_error "服务启动失败，请检查日志"
                fi
                ;;
            3)
                create_systemd_service "$arch"
                ;;
            4)
                log_info "手动启动命令:"
                echo -e "${GREEN}./hysteria-linux-${arch} server -c ${CONFIG_FILE}${NC}"
                echo ""
                echo -e "${YELLOW}后台运行:${NC}"
                echo -e "${GREEN}nohup ./hysteria-linux-${arch} server -c ${CONFIG_FILE} > hysteria.log 2>&1 &${NC}"
                ;;
            *)
                log_warn "无效选择，使用默认后台运行"
                nohup ./hysteria-linux-${arch} server -c "$CONFIG_FILE" > hysteria.log 2>&1 &
                ;;
        esac
    else
        # 非交互模式，后台启动
        log_info "非交互模式，自动后台启动服务..."
        nohup ./hysteria-linux-${arch} server -c "$CONFIG_FILE" > hysteria.log 2>&1 &
    fi
}

# ========== 创建 Systemd 服务 ==========
create_systemd_service() {
    local arch="$1"
    
    print_step "创建 Systemd 服务..."
    
    if [ "$EUID" -ne 0 ]; then
        log_warn "需要 root 权限创建系统服务"
        echo -e "${YELLOW}请以 root 身份运行以下命令:${NC}"
        echo ""
        cat << EOF
cat > /etc/systemd/system/hysteria2.service <<-'SERVICE_EOF'
[Unit]
Description=Hysteria2 Proxy Server
After=network.target nss-lookup.target

[Service]
Type=simple
User=$(whoami)
WorkingDirectory=$(pwd)
ExecStart=$(pwd)/hysteria-linux-${arch} server -c $(pwd)/${CONFIG_FILE}
Restart=on-failure
RestartSec=3
LimitNOFILE=infinity
StandardOutput=append:$(pwd)/hysteria.log
StandardError=append:$(pwd)/hysteria.log

[Install]
WantedBy=multi-user.target
SERVICE_EOF

systemctl daemon-reload
systemctl enable hysteria2
systemctl start hysteria2
systemctl status hysteria2
EOF
        echo ""
        return 1
    fi
    
    # 以 root 身份创建服务
    cat > /etc/systemd/system/hysteria2.service <<EOF
[Unit]
Description=Hysteria2 Proxy Server
After=network.target nss-lookup.target

[Service]
Type=simple
User=$(whoami)
WorkingDirectory=$(pwd)
ExecStart=$(pwd)/hysteria-linux-${arch} server -c $(pwd)/${CONFIG_FILE}
Restart=on-failure
RestartSec=3
LimitNOFILE=infinity
StandardOutput=append:$(pwd)/hysteria.log
StandardError=append:$(pwd)/hysteria.log

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable hysteria2
    systemctl start hysteria2
    
    sleep 1
    
    if systemctl is-active --quiet hysteria2; then
        log_success "Systemd 服务启动成功"
        echo ""
        echo -e "${GREEN}服务状态:${NC}"
        systemctl status hysteria2 --no-pager -l
        echo ""
        echo -e "${YELLOW}管理命令:${NC}"
        echo -e "启动: ${GREEN}systemctl start hysteria2${NC}"
        echo -e "停止: ${GREEN}systemctl stop hysteria2${NC}"
        echo -e "重启: ${GREEN}systemctl restart hysteria2${NC}"
        echo -e "状态: ${GREEN}systemctl status hysteria2${NC}"
        echo -e "日志: ${GREEN}journalctl -u hysteria2 -f${NC}"
    else
        log_error "Systemd 服务启动失败"
        journalctl -u hysteria2 --no-pager -n 20
    fi
}

# ========== 安装总结 ==========
show_installation_summary() {
    local server_ip="$1"
    local arch="$2"
    
    print_section "📊 安装总结"
    
    echo -e "${GREEN}✅ Hysteria2 安装完成！${NC}"
    echo ""
    
    echo -e "${YELLOW}📋 关键信息:${NC}"
    echo -e "${WHITE}├────────────────────────────────────────────${NC}"
    echo -e "  ${CYAN}服务器IP${NC}: ${GREEN}${server_ip}${NC}"
    echo -e "  ${CYAN}端口${NC}: ${GREEN}${SERVER_PORT}${NC}"
    echo -e "  ${CYAN}密码${NC}: ${GREEN}${AUTH_PASSWORD}${NC}"
    echo -e "  ${CYAN}架构${NC}: ${GREEN}${arch}${NC}"
    echo -e "${WHITE}└────────────────────────────────────────────${NC}"
    echo ""
    
    echo -e "${YELLOW}📁 重要文件:${NC}"
    echo -e "${WHITE}├────────────────────────────────────────────${NC}"
    echo -e "  📄 ${CONFIG_FILE} - 服务器配置文件"
    echo -e "  📄 client-info.txt - 客户端配置汇总"
    echo -e "  📄 install-record.json - 安装记录"
    echo -e "  📄 ${LOG_FILE} - 安装日志"
    echo -e "${WHITE}└────────────────────────────────────────────${NC}"
    echo ""
    
    echo -e "${YELLOW}🔗 快速链接:${NC}"
    local hysteria_link="hysteria2://${AUTH_PASSWORD}@${server_ip}:${SERVER_PORT}/?sni=${SNI}&alpn=${ALPN}&insecure=1#HY2-Node"
    echo -e "${GREEN}${hysteria_link}${NC}"
    echo ""
    
    echo -e "${YELLOW}🛠️ 后续步骤:${NC}"
    echo -e "${WHITE}├────────────────────────────────────────────${NC}"
    echo -e "  1. 配置防火墙开放端口 ${SERVER_PORT}"
    echo -e "  2. 客户端导入配置 (client-info.txt)"
    echo -e "  3. 测试连接: curl --http3 -vk https://${server_ip}:${SERVER_PORT}/"
    echo -e "  4. 监控日志: tail -f hysteria.log"
    echo -e "${WHITE}└────────────────────────────────────────────${NC}"
    echo ""
    
    # 显示二维码（如果可用且未禁用）
    if [ "$NO_QRCODE" = false ] && command -v qrencode &>/dev/null; then
        echo -e "${BG_YELLOW}══════════════════════════════════════════════════════════${NC}"
        echo -e "${WHITE}                    扫描二维码添加节点                     ${NC}"
        echo -e "${BG_YELLOW}══════════════════════════════════════════════════════════${NC}"
        echo ""
        echo "$hysteria_link" | qrencode -t UTF8
        echo ""
    fi
    
    echo -e "${BG_GREEN}══════════════════════════════════════════════════════════${NC}"
    echo -e "${WHITE}            🎉 安装完成！祝您使用愉快！                   ${NC}"
    echo -e "${BG_GREEN}══════════════════════════════════════════════════════════${NC}"
    echo ""
}

# ========== 主函数 ==========
main() {
    # 初始化日志
    echo "=== Hysteria2 安装开始 $(date) ===" > "$LOG_FILE"
    
    # 显示横幅
    print_banner
    
    # 解析参数
    parse_args "$@"
    
    # 确定端口（优先级：命令行 > 环境变量 > 默认）
    SERVER_PORT="${SERVER_PORT:-${DEFAULT_PORT}}"
    
    # 端口检查
    check_port "$SERVER_PORT"
    
    # 显示配置摘要
    print_section "⚙️ 配置摘要"
    echo -e "${WHITE}├────────────────────────────────────────────${NC}"
    echo -e "  ${CYAN}版本${NC}: ${GREEN}${HYSTERIA_VERSION}${NC}"
    echo -e "  ${CYAN}端口${NC}: ${GREEN}${SERVER_PORT}${NC}"
    echo -e "  ${CYAN}密码${NC}: ${GREEN}${AUTH_PASSWORD:0:8}****${NC}"
    echo -e "  ${CYAN}SNI${NC}: ${GREEN}${SNI}${NC}"
    echo -e "  ${CYAN}ALPN${NC}: ${GREEN}${ALPN}${NC}"
    echo -e "${WHITE}└────────────────────────────────────────────${NC}"
    echo ""
    
    # 备份现有配置
    backup_existing
    
    # 检测架构
    ARCH=$(get_architecture)
    log_info "系统架构: ${ARCH}"
    
    # 下载二进制文件
    download_binary "$ARCH"
    
    # 生成证书
    generate_certificate
    
    # 生成配置文件
    create_config
    
    # 获取服务器IP
    SERVER_IP=$(get_server_ip)
    
    # 生成客户端配置
    generate_client_configs "$SERVER_IP"
    
    # 美观显示节点信息
    show_node_info "$SERVER_IP"
    
    # 显示二维码
    show_qrcode "$SERVER_IP"
    
    # 显示启动指导
    show_startup_guide "$SERVER_IP"
    
    # 保存安装记录
    save_installation_record "$SERVER_IP" "$ARCH"
    
    # 安装总结
    show_installation_summary "$SERVER_IP" "$ARCH"
    
    # 询问是否启动服务
    ask_to_start_service "$ARCH"
    
    # 记录安装完成
    echo "=== Hysteria2 安装完成 $(date) ===" >> "$LOG_FILE"
    log_success "安装完成！详细日志: $LOG_FILE"
}

# ========== 脚本入口 ==========
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi