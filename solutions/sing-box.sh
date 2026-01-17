#!/usr/bin/env bash
# 版本: v1.0.1

set -euo pipefail

SCRIPT_NAME="sing-box"
SCRIPT_VERSION="1.0.1"
CONFIG_DIR="/etc/$SCRIPT_NAME"
BIN_FILE="/usr/local/bin/$SCRIPT_NAME"
SERVICE_FILE="/etc/systemd/system/$SCRIPT_NAME.service"
LOG_FILE="/var/log/$SCRIPT_NAME.log"
SUBSCRIBE_DIR="/etc/$SCRIPT_NAME/subscribe"
PORT_FILE="/etc/$SCRIPT_NAME/ports.conf"
USERS_FILE="/etc/$SCRIPT_NAME/users.json"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

error() { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }
info() { echo -e "${GREEN}[INFO]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
step() { echo -e "${BLUE}[STEP]${NC} $*"; }

check_root() {
    [[ $EUID -ne 0 ]] && error "必须使用 root 权限运行此脚本"
}

check_system() {
    if [[ -f /etc/redhat-release ]]; then
        SYSTEM="centos"
    elif grep -q "Ubuntu" /etc/os-release; then
        SYSTEM="ubuntu"
    elif grep -q "Debian" /etc/os-release; then
        SYSTEM="debian"
    else
        SYSTEM="unknown"
    fi
}

# ==================== 端口管理 ====================
init_ports() {
    mkdir -p "$(dirname "$PORT_FILE")"
    if [[ ! -f "$PORT_FILE" ]]; then
        echo "START_PORT=10000" > "$PORT_FILE"
        echo "LAST_PORT=10000" >> "$PORT_FILE"
        echo "PORT_INCREMENT=10" >> "$PORT_FILE"
    fi
    source "$PORT_FILE"
}

get_next_port() {
    init_ports
    NEXT_PORT=$((LAST_PORT + PORT_INCREMENT))
    echo "$LAST_PORT"
    sed -i "s/^LAST_PORT=.*/LAST_PORT=$NEXT_PORT/" "$PORT_FILE"
}

# ==================== 用户管理 ====================
init_users() {
    if [[ ! -f "$USERS_FILE" ]]; then
        echo '{"users": []}' > "$USERS_FILE"
    fi
}

add_user() {
    init_users
    local username password protocol port uuid
    
    echo -e "${CYAN}添加新用户${NC}"
    read -p "用户名: " username
    read -sp "密码: " password
    echo
    
    echo -e "${CYAN}选择协议:${NC}"
    echo "1) vmess"
    echo "2) vless"
    echo "3) trojan"
    echo "4) shadowsocks"
    read -p "选择 (1-4): " protocol_choice
    
    case $protocol_choice in
        1) protocol="vmess" ;;
        2) protocol="vless" ;;
        3) protocol="trojan" ;;
        4) protocol="shadowsocks" ;;
        *) protocol="vmess" ;;
    esac
    
    port=$(get_next_port)
    uuid=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || echo "$RANDOM$RANDOM")
    
    local user_config=$(cat << USER_EOF
{
    "username": "$username",
    "password": "$password",
    "protocol": "$protocol",
    "port": $port,
    "uuid": "$uuid"
}
USER_EOF
    )
    
    local temp_file=$(mktemp)
    jq ".users += [$user_config]" "$USERS_FILE" > "$temp_file" 2>/dev/null || {
        echo "$user_config" >> "$USERS_FILE.users"
        warn "jq 命令未安装，用户信息已保存到 $USERS_FILE.users"
    }
    [[ -f "$temp_file" ]] && mv "$temp_file" "$USERS_FILE"
    
    info "用户添加成功:"
    echo "  协议: $protocol"
    echo "  端口: $port"
    echo "  UUID: $uuid"
}

list_users() {
    init_users
    if [[ -f "$USERS_FILE" ]]; then
        echo -e "${CYAN}用户列表:${NC}"
        jq -r '.users[] | "\(.username) | \(.protocol) | 端口:\(.port) | UUID:\(.uuid)"' "$USERS_FILE" 2>/dev/null || \
        cat "$USERS_FILE.users" 2>/dev/null || \
        echo "无用户"
    fi
}

# ==================== 订阅生成 ====================
generate_subscribe() {
    mkdir -p "$SUBSCRIBE_DIR"
    local server_ip=$(curl -s ip.sb 2>/dev/null || echo "127.0.0.1")
    
    if [[ -f "$USERS_FILE" ]]; then
        local subscribe_url="http://$server_ip:8080/subscribe/$SCRIPT_NAME"
        
        cat > "$SUBSCRIBE_DIR/index.html" << HTML_EOF
<!DOCTYPE html>
<html>
<head><title>Subscribe</title></head>
<body>
<h1>$SCRIPT_NAME 订阅</h1>
<p>服务器: $server_ip</p>
<p>更新时间: $(date)</p>
<pre>

# ==================== 更多功能 ====================
update_singbox() {
    step "检查更新..."
    
    local current_version=$("$BIN_FILE" version 2>/dev/null | head -1 || echo "未知")
    info "当前版本: $current_version"
    
    local latest_url="https://api.github.com/repos/SagerNet/sing-box/releases/latest"
    local latest_version=$(curl -s $latest_url | grep '"tag_name":' | cut -d '"' -f 4)
    
    if [[ "$current_version" == *"$latest_version"* ]]; then
        info "已是最新版本"
        return
    fi
    
    info "发现新版本: $latest_version"
    read -p "是否更新? (y/N): " confirm
    [[ "$confirm" != "y" ]] && return
    
    systemctl stop "$SCRIPT_NAME"
    
    local download_url=$(curl -s $latest_url | grep "browser_download_url.*linux-amd64.tar.gz" | cut -d '"' -f 4)
    wget -q "$download_url" -O /tmp/sing-box.tar.gz
    tar -xzf /tmp/sing-box.tar.gz -C /tmp
    cp /tmp/sing-box-*/sing-box "$BIN_FILE"
    chmod +x "$BIN_FILE"
    
    systemctl start "$SCRIPT_NAME"
    info "✅ 已更新到 $latest_version"
}

backup_config() {
    local backup_dir="/backup/$SCRIPT_NAME"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    mkdir -p "$backup_dir"
    
    tar -czf "$backup_dir/config_$timestamp.tar.gz" -C /etc "$SCRIPT_NAME"
    info "配置已备份到: $backup_dir/config_$timestamp.tar.gz"
}

restore_config() {
    local backup_dir="/backup/$SCRIPT_NAME"
    if [[ ! -d "$backup_dir" ]]; then
        error "备份目录不存在"
    fi
    
    echo -e "${CYAN}可用备份:${NC}"
    ls -lh "$backup_dir"/*.tar.gz 2>/dev/null | nl || {
        warn "无备份文件"
        return
    }
    
    read -p "选择备份编号: " choice
    local backup_file=$(ls "$backup_dir"/*.tar.gz | sed -n "${choice}p")
    
    [[ -z "$backup_file" ]] && error "无效选择"
    
    read -p "确认恢复备份 $backup_file? (y/N): " confirm
    [[ "$confirm" != "y" ]] && return
    
    systemctl stop "$SCRIPT_NAME"
    rm -rf "$CONFIG_DIR"
    tar -xzf "$backup_file" -C /etc
    systemctl start "$SCRIPT_NAME"
    info "✅ 配置已恢复"
}

show_stats() {
    if systemctl is-active "$SCRIPT_NAME" >/dev/null 2>&1; then
        info "运行统计:"
        echo "  运行时间: $(systemctl show -p ActiveEnterTimestamp "$SCRIPT_NAME" | cut -d= -f2)"
        echo "  内存使用: $(ps aux | grep sing-box | grep -v grep | awk '{print $6/1024" MB"}')"
        echo "  CPU 使用: $(ps aux | grep sing-box | grep -v grep | awk '{print $3"%"}')"
        
        if [[ -f "$LOG_FILE" ]]; then
            echo "  连接数: $(grep -c "connection" "$LOG_FILE" 2>/dev/null || echo "0")"
            echo "  错误数: $(grep -c "error\|failed" "$LOG_FILE" 2>/dev/null || echo "0")"
        fi
    else
        warn "服务未运行"
    fi
}

change_port() {
    read -p "当前管理端口(8080): " new_port
    new_port=${new_port:-8080}
    
    if [[ "$new_port" =~ ^[0-9]+$ ]] && [ "$new_port" -ge 1024 ] && [ "$new_port" -le 65535 ]; then
        systemctl stop "$SCRIPT_NAME"
        
        # 更新配置文件端口
        sed -i "s/\"listen_port\": 8080/\"listen_port\": $new_port/" "$CONFIG_DIR/config.json"
        
        systemctl start "$SCRIPT_NAME"
        info "✅ 端口已更改为: $new_port"
    else
        error "无效端口号"
    fi
}

# ==================== 增强菜单 ====================
show_enhanced_menu() {
    while true; do
        clear
        echo -e "${PURPLE}================================${NC}"
        echo -e "${PURPLE}    sing-box 高级管理菜单       ${NC}"
        echo -e "${PURPLE}================================${NC}"
        echo -e "${CYAN}1) 安装/更新${NC}"
        echo "  1.1) 安装 sing-box"
        echo "  1.2) 检查更新"
        echo "  1.3) 重新安装"
        
        echo -e "${CYAN}2) 服务管理${NC}"
        echo "  2.1) 启动服务"
        echo "  2.2) 停止服务"
        echo "  2.3) 重启服务"
        echo "  2.4) 查看状态"
        echo "  2.5) 查看日志"
        
        echo -e "${CYAN}3) 配置管理${NC}"
        echo "  3.1) 编辑配置"
        echo "  3.2) 备份配置"
        echo "  3.3) 恢复配置"
        echo "  3.4) 修改端口"
        
        echo -e "${CYAN}4) 用户管理${NC}"
        echo "  4.1) 添加用户"
        echo "  4.2) 列出用户"
        echo "  4.3) 生成订阅"
        
        echo -e "${CYAN}5) 系统工具${NC}"
        echo "  5.1) 查看统计"
        echo "  5.2) 清理日志"
        echo "  5.3) 测试连接"
        
        echo -e "${RED}6) 退出${NC}"
        echo -e "${PURPLE}================================${NC}"
        
        read -p "请选择 (1.1-6): " choice
        
        case $choice in
            1.1) install_singbox ;;
            1.2) update_singbox ;;
            1.3) uninstall_singbox && install_singbox ;;
            2.1) systemctl start "$SCRIPT_NAME" && info "服务已启动" ;;
            2.2) systemctl stop "$SCRIPT_NAME" && info "服务已停止" ;;
            2.3) systemctl restart "$SCRIPT_NAME" && info "服务已重启" ;;
            2.4) show_status ;;
            2.5) show_log ;;
            3.1) ${EDITOR:-vi} "$CONFIG_DIR/config.json" ;;
            3.2) backup_config ;;
            3.3) restore_config ;;
            3.4) change_port ;;
            4.1) add_user ;;
            4.2) list_users ;;
            4.3) generate_subscribe ;;
            5.1) show_stats ;;
            5.2) echo "" > "$LOG_FILE" && info "日志已清理" ;;
            5.3) curl -s http://localhost:8080 >/dev/null && info "连接正常" || warn "连接失败" ;;
            6) exit 0 ;;
            *) warn "无效选择" ;;
        esac
        
        read -p "按回车键继续..."
    done
}

# 更新主函数
main() {
    check_root
    check_system
    
    case "${1:-}" in
        install)
            install_singbox
            ;;
        uninstall)
            uninstall_singbox
            ;;
        start)
            systemctl start "$SCRIPT_NAME"
            info "服务已启动"
            ;;
        stop)
            systemctl stop "$SCRIPT_NAME"
            info "服务已停止"
            ;;
        restart)
            systemctl restart "$SCRIPT_NAME"
            info "服务已重启"
            ;;
        status)
            show_status
            ;;
        log)
            show_log
            ;;
        config)
            ${EDITOR:-vi} "$CONFIG_DIR/config.json"
            ;;
        update)
            update_singbox
            ;;
        backup)
            backup_config
            ;;
        restore)
            restore_config
            ;;
        stats)
            show_stats
            ;;
        port)
            change_port
            ;;
        subscribe)
            generate_subscribe
            ;;
        "add-user")
            add_user
            ;;
        "list-users")
            list_users
            ;;
        menu)
            show_menu
            ;;
        advanced)
            show_enhanced_menu
            ;;
        -h|--help)
            echo "用法: $0 [command]"
            echo "命令:"
            echo "  install      安装"
            echo "  uninstall    卸载"
            echo "  start/stop/restart 服务控制"
            echo "  status       状态"
            echo "  log          日志"
            echo "  config       编辑配置"
            echo "  update       更新"
            echo "  backup       备份"
            echo "  restore      恢复"
            echo "  stats        统计"
            echo "  port         修改端口"
            echo "  subscribe    生成订阅"
            echo "  add-user     添加用户"
            echo "  list-users   列出用户"
            echo "  menu         简易菜单"
            echo "  advanced     高级菜单"
            echo "  -h, --help   帮助"
            echo "  -v, --version 版本"
            ;;
        -v|--version)
            echo "$SCRIPT_NAME version: $SCRIPT_VERSION"
            ;;
        *)
            if [[ -z "$1" ]]; then
                show_enhanced_menu
            else
                error "未知参数: $1"
            fi
            ;;
    esac
}

# ==================== 协议配置管理 ====================
show_protocols() {
    echo -e "${CYAN}支持的协议:${NC}"
    echo "1) VMESS + TLS"
    echo "2) VLESS + TLS + WS"
    echo "3) Trojan + TLS"
    echo "4) Shadowsocks"
    echo "5) Hysteria2"
    echo "6) TUIC"
    echo "7) 混合端口 (Mixed)"
}

configure_protocol() {
    echo -e "${CYAN}选择协议类型:${NC}"
    show_protocols
    
    read -p "选择 (1-7): " proto_choice
    
    local protocol_name port
    case $proto_choice in
        1) protocol_name="vmess+tls" ;;
        2) protocol_name="vless+ws+tls" ;;
        3) protocol_name="trojan+tls" ;;
        4) protocol_name="shadowsocks" ;;
        5) protocol_name="hysteria2" ;;
        6) protocol_name="tuic" ;;
        7) protocol_name="mixed" ;;
        *) protocol_name="mixed" ;;
    esac
    
    read -p "监听端口 (默认: 8080): " port
    port=${port:-8080}
    
    info "已选择协议: $protocol_name, 端口: $port"
    
    # 生成对应协议的配置模板
    generate_protocol_config "$protocol_name" "$port"
}

generate_protocol_config() {
    local proto="$1"
    local port="$2"
    
    case $proto in
        "vmess+tls")
            cat > "$CONFIG_DIR/config.json" << VMESS_EOF
{
  "log": {"level": "info", "output": "$LOG_FILE"},
  "inbounds": [{
    "type": "vmess",
    "listen": "::",
    "listen_port": $port,
    "users": [{
      "uuid": "$(cat /proc/sys/kernel/random/uuid 2>/dev/null || echo $(uuidgen))",
      "alterId": 0
    }],
    "tls": {
      "enabled": true,
      "server_name": "example.com",
      "certificate_path": "/path/to/cert.pem",
      "key_path": "/path/to/key.pem"
    }
  }],
  "outbounds": [{"type": "direct"}]
}
VMESS_EOF
            ;;
        "mixed")
            cat > "$CONFIG_DIR/config.json" << MIXED_EOF
{
  "log": {"level": "info", "output": "$LOG_FILE"},
  "inbounds": [{
    "type": "mixed",
    "listen": "::",
    "listen_port": $port,
    "sniff": true,
    "users": []
  }],
  "outbounds": [{"type": "direct"}]
}
MIXED_EOF
            ;;
        *)
            warn "协议配置模板未实现: $proto"
            return 1
            ;;
    esac
    
    info "配置文件已生成: $CONFIG_DIR/config.json"
    echo "请根据实际情况修改证书路径等配置"
}

# ==================== 流量统计 ====================
show_traffic() {
    if ! systemctl is-active "$SCRIPT_NAME" >/dev/null 2>&1; then
        warn "服务未运行"
        return
    fi
    
    local pid=$(pgrep -f "sing-box run")
    if [[ -n "$pid" ]]; then
        echo -e "${CYAN}实时流量统计 (按 Ctrl+C 退出):${NC}"
        
        # 使用 iftop 或基本统计
        if command -v iftop >/dev/null 2>&1; then
            iftop -i $(netstat -tunlp 2>/dev/null | grep $pid | head -1 | awk '{print $4}' | cut -d: -f1) 2>/dev/null || \
            echo "需要安装 iftop: apt install iftop / yum install iftop"
        else
            echo "当前连接数: $(ss -tunp 2>/dev/null | grep $pid | wc -l)"
            echo "使用 netstat -tunlp | grep $pid 查看详细连接"
        fi
    else
        warn "未找到运行进程"
    fi
}

# ==================== TLS证书管理 ====================
manage_certificates() {
    local cert_dir="/etc/$SCRIPT_NAME/certificates"
    mkdir -p "$cert_dir"
    
    while true; do
        clear
        echo -e "${CYAN}TLS证书管理${NC}"
        echo "1) 生成自签名证书"
        echo "2) 上传已有证书"
        echo "3) 查看证书信息"
        echo "4) 返回主菜单"
        
        read -p "选择: " cert_choice
        
        case $cert_choice in
            1)
                generate_self_signed_cert "$cert_dir"
                ;;
            2)
                upload_certificate "$cert_dir"
                ;;
            3)
                show_cert_info "$cert_dir"
                ;;
            4)
                break
                ;;
            *)
                warn "无效选择"
                ;;
        esac
        read -p "按回车继续..."
    done
}

generate_self_signed_cert() {
    local cert_dir="$1"
    
    read -p "域名 (默认: localhost): " domain
    domain=${domain:-localhost}
    
    read -p "有效期天数 (默认: 365): " days
    days=${days:-365}
    
    openssl req -x509 -nodes -days $days -newkey rsa:2048 \
        -keyout "$cert_dir/$domain.key" \
        -out "$cert_dir/$domain.crt" \
        -subj "/C=US/ST=State/L=City/O=Organization/CN=$domain" 2>/dev/null
    
    if [[ $? -eq 0 ]]; then
        info "证书已生成:"
        echo "  证书: $cert_dir/$domain.crt"
        echo "  私钥: $cert_dir/$domain.key"
    else
        error "证书生成失败"
    fi
}

# ==================== 多节点管理 ====================
manage_nodes() {
    local nodes_dir="/etc/$SCRIPT_NAME/nodes"
    mkdir -p "$nodes_dir"
    
    while true; do
        clear
        echo -e "${CYAN}节点管理${NC}"
        echo "1) 添加节点"
        echo "2) 列出节点"
        echo "3) 切换节点"
        echo "4) 删除节点"
        echo "5) 测试节点"
        echo "6) 返回主菜单"
        
        read -p "选择: " node_choice
        
        case $node_choice in
            1) add_node "$nodes_dir" ;;
            2) list_nodes "$nodes_dir" ;;
            3) switch_node "$nodes_dir" ;;
            4) delete_node "$nodes_dir" ;;
            5) test_nodes "$nodes_dir" ;;
            6) break ;;
            *) warn "无效选择" ;;
        esac
        read -p "按回车继续..."
    done
}

add_node() {
    local nodes_dir="$1"
    
    read -p "节点名称: " node_name
    read -p "服务器地址: " server
    read -p "端口: " port
    read -p "协议类型: " protocol
    read -p "密码/UUID: " secret
    
    cat > "$nodes_dir/$node_name.json" << NODE_EOF
{
    "name": "$node_name",
    "server": "$server",
    "port": $port,
    "protocol": "$protocol",
    "secret": "$secret",
    "added": "$(date)"
}
NODE_EOF
    
    info "节点已添加: $node_name"
}

# ==================== 性能监控 ====================
monitor_performance() {
    echo -e "${CYAN}性能监控${NC}"
    echo "按 Ctrl+C 退出监控"
    
    while true; do
        clear
        local pid=$(pgrep -f "sing-box run")
        
        if [[ -n "$pid" ]]; then
            # CPU 使用率
            local cpu=$(ps -p $pid -o %cpu --no-headers)
            # 内存使用
            local mem=$(ps -p $pid -o rss --no-headers)
            mem=$((mem/1024))  # 转换为 MB
            
            # 连接数
            local connections=$(ss -tunp 2>/dev/null | grep $pid | wc -l)
            
            echo "进程ID: $pid"
            echo "CPU 使用: ${cpu}%"
            echo "内存使用: ${mem}MB"
            echo "连接数: $connections"
            echo "运行时间: $(ps -p $pid -o etime --no-headers)"
            
            # 简单的 ASCII 图表
            echo -ne "CPU使用图表: "
            local cpu_int=${cpu%.*}
            for ((i=0; i<cpu_int/2; i++)); do echo -n "█"; done
            echo ""
            
            echo -ne "内存使用图表: "
            local mem_blocks=$((mem/10))
            for ((i=0; i<mem_blocks && i<20; i++)); do echo -n "▓"; done
            echo ""
        else
            warn "服务未运行"
        fi
        
        sleep 2
    done
}

# ==================== 批量操作 ====================
batch_operations() {
    echo -e "${CYAN}批量操作${NC}"
    echo "1) 批量添加用户"
    echo "2) 批量生成配置"
    echo "3) 批量测试端口"
    
    read -p "选择: " batch_choice
    
    case $batch_choice in
        1)
            read -p "添加用户数量: " user_count
            for ((i=1; i<=user_count; i++)); do
                echo "添加用户 #$i"
                add_user
                sleep 1
            done
            ;;
        2)
            read -p "生成配置文件数量: " config_count
            for ((i=1; i<=config_count; i++)); do
                local port=$((8080 + i))
                generate_protocol_config "mixed" $port
                echo "配置 $i 生成完成 (端口: $port)"
            done
            ;;
        3)
            read -p "起始端口: " start_port
            read -p "结束端口: " end_port
            for ((port=start_port; port<=end_port; port++)); do
                if nc -z localhost $port 2>/dev/null; then
                    echo "端口 $port: 开放"
                else
                    echo "端口 $port: 关闭"
                fi
            done
            ;;
        *)
            warn "无效选择"
            ;;
    esac
}

# ==================== 更新主函数 ====================
main() {
    check_root
    check_system
    
    case "${1:-}" in
        # 原有命令...
        protocol)
            configure_protocol
            ;;
        traffic)
            show_traffic
            ;;
        cert)
            manage_certificates
            ;;
        nodes)
            manage_nodes
            ;;
        monitor)
            monitor_performance
            ;;
        batch)
            batch_operations
            ;;
        # ... 其他原有 case 语句 ...
        *)
            # 如果上面没匹配，检查是否是新的高级命令
            if [[ -z "$1" ]]; then
                show_enhanced_menu
            else
                # 最后尝试执行未知命令
                warn "未知命令: $1"
                echo "使用 $0 --help 查看可用命令"
                exit 1
            fi
            ;;
    esac
}

# 更新帮助信息
cat > /tmp/help_update << 'HELP_EOF'
    # ... 在原有帮助信息后添加 ...
    echo "高级功能:"
    echo "  protocol       配置协议"
    echo "  traffic        流量统计"
    echo "  cert           TLS证书管理"
    echo "  nodes          多节点管理"
    echo "  monitor        性能监控"
    echo "  batch          批量操作"
HELP_EOF

# 更新帮助函数部分
sed -i '/echo "命令:"/,/^            ;;/ {
    /echo "命令:/a\
    echo "高级功能:"\
    echo "  protocol       配置协议"\
    echo "  traffic        流量统计"\
    echo "  cert           TLS证书管理"\
    echo "  nodes          多节点管理"\
    echo "  monitor        性能监控"\
    echo "  batch          批量操作"
}' sing-box.sh

# ==================== 补充函数实现 ====================
upload_certificate() {
    local cert_dir="$1"
    
    echo "请将证书文件(.crt)和私钥文件(.key)复制到: $cert_dir/"
    echo "然后运行:"
    echo "  chmod 600 $cert_dir/*.key"
    echo "配置文件需要手动更新证书路径"
    
    ls -la "$cert_dir/" 2>/dev/null || info "目录为空"
}

show_cert_info() {
    local cert_dir="$1"
    
    if ls "$cert_dir"/*.crt 1>/dev/null 2>&1; then
        for cert in "$cert_dir"/*.crt; do
            echo -e "${CYAN}证书: $(basename $cert)${NC}"
            openssl x509 -in "$cert" -noout -subject -dates 2>/dev/null | sed 's/^/  /'
            echo ""
        done
    else
        warn "未找到证书文件"
    fi
}

list_nodes() {
    local nodes_dir="$1"
    
    if ls "$nodes_dir"/*.json 1>/dev/null 2>&1; then
        echo -e "${CYAN}可用节点:${NC}"
        for node in "$nodes_dir"/*.json; do
            local name=$(jq -r '.name' "$node" 2>/dev/null)
            local server=$(jq -r '.server' "$node" 2>/dev/null)
            local port=$(jq -r '.port' "$node" 2>/dev/null)
            echo "  $name: $server:$port"
        done
    else
        info "暂无节点配置"
    fi
}

switch_node() {
    local nodes_dir="$1"
    
    list_nodes "$nodes_dir"
    
    read -p "输入节点名称: " node_name
    local node_file="$nodes_dir/$node_name.json"
    
    if [[ -f "$node_file" ]]; then
        info "切换到节点: $node_name"
        # 这里可以添加实际的切换逻辑
        # 比如更新配置文件并重启服务
    else
        warn "节点不存在: $node_name"
    fi
}

delete_node() {
    local nodes_dir="$1"
    
    list_nodes "$nodes_dir"
    
    read -p "输入要删除的节点名称: " node_name
    local node_file="$nodes_dir/$node_name.json"
    
    if [[ -f "$node_file" ]]; then
        rm -f "$node_file"
        info "已删除节点: $node_name"
    else
        warn "节点不存在"
    fi
}

test_nodes() {
    local nodes_dir="$1"
    
    for node in "$nodes_dir"/*.json 2>/dev/null; do
        local server=$(jq -r '.server' "$node" 2>/dev/null)
        local port=$(jq -r '.port' "$node" 2>/dev/null)
        local name=$(jq -r '.name' "$node" 2>/dev/null)
        
        echo -n "测试 $name ($server:$port)... "
        if timeout 2 nc -z "$server" "$port" 2>/dev/null; then
            echo -e "${GREEN}✓ 可用${NC}"
        else
            echo -e "${RED}✗ 不可用${NC}"
        fi
    done
}

# 确保主函数能调用新命令
main() {
    check_root
    check_system
    
    case "${1:-}" in
        # ... 原有命令保持不变 ...
        protocol)
            configure_protocol
            ;;
        traffic)
            show_traffic
            ;;
        cert)
            manage_certificates
            ;;
        nodes)
            manage_nodes
            ;;
        monitor)
            monitor_performance
            ;;
        batch)
            batch_operations
            ;;
        # ... 原有的其他命令 ...
        install)
            install_singbox
            ;;
        uninstall)
            uninstall_singbox
            ;;
        start)
            systemctl start "$SCRIPT_NAME"
            info "服务已启动"
            ;;
        stop)
            systemctl stop "$SCRIPT_NAME"
            info "服务已停止"
            ;;
        restart)
            systemctl restart "$SCRIPT_NAME"
            info "服务已重启"
            ;;
        status)
            show_status
            ;;
        log)
            show_log
            ;;
        config)
            ${EDITOR:-vi} "$CONFIG_DIR/config.json"
            ;;
        update)
            update_singbox
            ;;
        backup)
            backup_config
            ;;
        restore)
            restore_config
            ;;
        stats)
            show_stats
            ;;
        port)
            change_port
            ;;
        subscribe)
            generate_subscribe
            ;;
        "add-user")
            add_user
            ;;
        "list-users")
            list_users
            ;;
        menu)
            show_menu
            ;;
        advanced)
            show_enhanced_menu
            ;;
        -h|--help)
            echo "用法: $0 [command]"
            echo "基本命令:"
            echo "  install      安装"
            echo "  uninstall    卸载"
            echo "  start/stop/restart 服务控制"
            echo "  status       状态"
            echo "  log          日志"
            echo "  config       编辑配置"
            echo "  update       更新"
            echo "  backup       备份"
            echo "  restore      恢复"
            echo "  stats        统计"
            echo "  port         修改端口"
            echo "  subscribe    生成订阅"
            echo "  add-user     添加用户"
            echo "  list-users   列出用户"
            echo "  menu         简易菜单"
            echo "  advanced     高级菜单"
            echo "高级功能:"
            echo "  protocol     配置协议"
            echo "  traffic      流量统计"
            echo "  cert         TLS证书管理"
            echo "  nodes        多节点管理"
            echo "  monitor      性能监控"
            echo "  batch        批量操作"
            echo "  -h, --help   帮助"
            echo "  -v, --version 版本"
            ;;
        -v|--version)
            echo "$SCRIPT_NAME version: $SCRIPT_VERSION"
            ;;
        *)
            if [[ -z "$1" ]]; then
                show_enhanced_menu
            else
                error "未知参数: $1"
            fi
            ;;
    esac
}
