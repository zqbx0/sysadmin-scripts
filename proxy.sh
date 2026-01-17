#!/usr/bin/env bash
#
# Proxy Scripts Manager v1.0.1
# 重构版本 - 统一管理所有代理方案
#
#
# Proxy Scripts Manager
# 智能代理脚本管理器
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

info() { echo -e "${GREEN}[INFO]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }
debug() { echo -e "${BLUE}[DEBUG]${NC} $*"; }

# 检查冲突
check_conflicts() {
    local conflict_found=0
    
    # 检查服务状态
    services=("sing-box" "sba" "argox" "hysteria2")
    for service in "${services[@]}"; do
        if systemctl is-active "$service" 2>/dev/null || \
           ps aux | grep -v grep | grep -q "$service"; then
            warn "检测到 $service 正在运行"
            conflict_found=1
        fi
    done
    
    if [ $conflict_found -eq 1 ]; then
        echo
        read -p "检测到可能冲突的服务，是否继续？(y/N): " confirm
        [[ ! "$confirm" =~ ^[Yy]$ ]] && exit 1
    fi
}

# 显示菜单
show_menu() {
    echo -e "\n${BLUE}╔════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║     📦 代理脚本智能管理器 v1.0        ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
    echo
    echo "主要解决方案："
    echo "  1) 🚀 Sing-box 完整版 (11协议+订阅+Argo)"
    echo "  2) ⚡ SBA 简化版 (Sing-box核心+Argo)"
    echo "  3) 🛡️  ArgoX 传统版 (Xray+Argo)"
    echo "  4) 🎯 四合一精简版 (精选4协议)"
    echo "  5) 🏎️  Hysteria2 极速版"
    echo
    echo "工具脚本："
    echo "  6) ⚙️  TCP Brutal 加速模块"
    echo "  7) 🐳 Docker 环境初始化"
    echo "  8) 🧪 部署测试"
    echo
    echo "管理功能："
    echo "  9) 📊 方案对比"
    echo "  10) 🧹 清理所有"
    echo "  11) 🔄 迁移助手"
    echo "  0) ❌ 退出"
    echo
}

# 主逻辑
main() {
    local choice
    
    while true; do
        show_menu
        read -p "请选择 (0-11): " choice
        
        case $choice in
            1)
                check_conflicts
                info "启动 Sing-box 完整版..."
                "$SCRIPT_DIR/solutions/sing-box.sh" "$@"
                break
                ;;
            2)
                check_conflicts
                info "启动 SBA 简化版..."
                "$SCRIPT_DIR/solutions/sba.sh" "$@"
                break
                ;;
            3)
                check_conflicts
                info "启动 ArgoX 传统版..."
                "$SCRIPT_DIR/solutions/argox.sh" "$@"
                break
                ;;
            4)
                check_conflicts
                info "启动四合一精简版..."
                "$SCRIPT_DIR/solutions/sing-box-four-in-one.sh" "$@"
                break
                ;;
            5)
                check_conflicts
                info "启动 Hysteria2 极速版..."
                "$SCRIPT_DIR/solutions/hysteria2.sh" "$@"
                break
                ;;
            6)
                info "安装 TCP Brutal 加速..."
                "$SCRIPT_DIR/tools/tcp-brutal.sh" "$@"
                break
                ;;
            7)
                info "初始化 Docker 环境..."
                "$SCRIPT_DIR/tools/docker_init.sh" "$@"
                break
                ;;
            8)
                info "运行部署测试..."
                "$SCRIPT_DIR/tools/test_deployment.sh" "$@"
                break
                ;;
            9)
                show_comparison
                ;;
            10)
                cleanup_all
                ;;
            11)
                migration_helper
                ;;
            0)
                info "再见！"
                exit 0
                ;;
            *)
                warn "无效选择，请重新输入"
                ;;
        esac
    done
}

# 方案对比
show_comparison() {
    echo -e "\n${YELLOW}=== 方案对比 ===${NC}"
    echo "┌─────────────────┬─────────┬─────────┬────────────┐"
    echo "│ 方案            │ 大小    │ 协议数  │ 特点       │"
    echo "├─────────────────┼─────────┼─────────┼────────────┤"
    echo "│ Sing-box 完整版 │ 195K    │ 11      │ 功能最全   │"
    echo "│ SBA 简化版      │ 94K     │ 5-6     │ 轻量快速   │"
    echo "│ ArgoX 传统版    │ 93K     │ 8-9     │ 兼容性好   │"
    echo "│ 四合一精简版    │ 66K     │ 4       │ 新手友好   │"
    echo "│ Hysteria2       │ 40K     │ 1       │ 极速简单   │"
    echo "└─────────────────┴─────────┴─────────┴────────────┘"
    echo
    read -p "按回车继续..."
}

# 清理所有
cleanup_all() {
    echo -e "\n${RED}⚠️  警告：这将清理所有代理服务${NC}"
    read -p "确认清理？(输入 'YES' 确认): " confirm
    
    if [ "$confirm" = "YES" ]; then
        info "开始清理..."
        
        # 停止并禁用服务
        for service in sing-box sba argox hysteria2; do
            systemctl stop "$service" 2>/dev/null || true
            systemctl disable "$service" 2>/dev/null || true
        done
        
        # 清理工作目录
        rm -rf /etc/sing-box /etc/sba /etc/argox /etc/hysteria2 2>/dev/null || true
        
        # 清理临时文件
        rm -rf /tmp/sing-box /tmp/sba /tmp/argox /tmp/hysteria2 2>/dev/null || true
        
        info "清理完成！"
    else
        info "取消清理"
    fi
    echo
    read -p "按回车继续..."
}

# 迁移助手
migration_helper() {
    echo -e "\n${BLUE}=== 迁移助手 ===${NC}"
    echo "请选择迁移方向："
    echo "1) Sing-box → SBA"
    echo "2) SBA → Sing-box"
    echo "3) ArgoX → Sing-box"
    echo "4) Sing-box → Hysteria2"
    echo "0) 返回"
    
    read -p "选择: " mig_choice
    
    case $mig_choice in
        1)
            info "正在从 Sing-box 迁移到 SBA..."
            # 这里可以添加迁移逻辑
            ;;
        2)
            info "正在从 SBA 迁移到 Sing-box..."
            ;;
        3)
            info "正在从 ArgoX 迁移到 Sing-box..."
            ;;
        4)
            info "正在从 Sing-box 迁移到 Hysteria2..."
            ;;
        *)
            return
            ;;
    esac
}

# 启动脚本
main "$@"
