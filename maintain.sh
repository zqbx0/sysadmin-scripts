#!/usr/bin/env bash
# sysadmin-scripts 项目维护工具

set -euo pipefail

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

error() { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }
info() { echo -e "${GREEN}[INFO]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
step() { echo -e "${BLUE}[STEP]${NC} $*"; }

# 显示帮助
show_help() {
    cat << HELP
sysadmin-scripts 项目维护工具

用法: $0 [命令]

命令:
  check         检查项目完整性
  backup        备份配置文件
  restore       恢复配置文件
  clean         清理临时文件
  update        更新所有脚本
  stats         显示项目统计信息
  test          运行测试
  --help, -h    显示此帮助信息

示例:
  $0 check        # 检查项目
  $0 backup       # 备份配置
  $0 clean        # 清理文件
HELP
}

# 检查项目完整性
check_project() {
    step "检查项目完整性..."
    
    echo "1. 检查必要目录:"
    for dir in solutions tools tools/network tools/system tools/maintenance; do
        if [ -d "$dir" ]; then
            echo "  ✅ $dir"
        else
            echo "  ❌ $dir - 不存在"
        fi
    done
    
    echo -e "\n2. 检查核心脚本:"
    for script in solutions/hysteria2.sh solutions/sing-box.sh solutions/sing-box-four-in-one.sh; do
        if [ -f "$script" ]; then
            if [ -x "$script" ]; then
                echo "  ✅ $script (可执行)"
            else
                echo "  ⚠️  $script (不可执行)"
                chmod +x "$script" 2>/dev/null && echo "    已添加执行权限"
            fi
        else
            echo "  ❌ $script - 不存在"
        fi
    done
    
    echo -e "\n3. 检查语法:"
    for script in solutions/*.sh; do
        if bash -n "$script" 2>/dev/null; then
            echo "  ✅ $(basename "$script") 语法正确"
        else
            echo "  ❌ $(basename "$script") 语法错误"
        fi
    done
    
    echo -e "\n4. 文件统计:"
    echo "  总文件数: $(find . -type f | wc -l)"
    echo "  目录大小: $(du -sh . | cut -f1)"
}

# 备份配置文件
backup_config() {
    local backup_dir="backups/$(date +%Y%m%d_%H%M%S)"
    step "备份到: $backup_dir"
    
    mkdir -p "$backup_dir"
    
    # 备份解决方案
    cp -r solutions/ "$backup_dir/"
    
    # 备份配置文件
    cp config.conf "$backup_dir/" 2>/dev/null || true
    
    # 创建备份信息
    cat > "$backup_dir/backup.info" << INFO
备份时间: $(date)
项目版本: $(cat VERSION 2>/dev/null || echo "未知")
文件数量: $(find solutions/ -type f | wc -l)
INFO
    
    info "备份完成: $backup_dir"
    du -sh "$backup_dir"
}

# 清理临时文件
clean_files() {
    step "清理临时文件..."
    
    # 清理日志文件
    find . -name "*.log" -type f -delete 2>/dev/null && info "清理日志文件"
    find . -name "*.tmp" -type f -delete 2>/dev/null && info "清理临时文件"
    find . -name "*~" -type f -delete 2>/dev/null && info "清理备份文件"
    
    # 清理空目录
    find . -type d -empty -delete 2>/dev/null && info "清理空目录"
    
    info "清理完成"
}

# 显示统计信息
show_stats() {
    step "项目统计信息:"
    
    echo "📊 基本统计:"
    echo "  目录大小: $(du -sh . | cut -f1)"
    echo "  文件总数: $(find . -type f | wc -l)"
    echo "  目录总数: $(find . -type d | wc -l)"
    
    echo -e "\n📁 目录结构:"
    find . -type d | sort | sed 's|/[^/]*/|/  |g;s|/[^/]*$|/|' | uniq
    
    echo -e "\n🔧 脚本统计:"
    echo "  Shell脚本: $(find . -name "*.sh" -type f | wc -l) 个"
    echo "  配置文件: $(find . -name "*.conf" -type f | wc -l) 个"
    echo "  文档文件: $(find . -name "*.md" -type f | wc -l) 个"
    
    echo -e "\n📈 Git 信息:"
    git log --oneline -5 2>/dev/null || echo "  无Git信息"
}

# 运行测试
run_tests() {
    step "运行测试..."
    
    # 测试脚本语法
    echo "1. 语法测试:"
    for script in solutions/*.sh; do
        if bash -n "$script"; then
            echo "  ✅ $(basename "$script")"
        else
            echo "  ❌ $(basename "$script")"
        fi
    done
    
    # 测试帮助信息
    echo -e "\n2. 帮助信息测试:"
    for script in solutions/*.sh; do
        if "./$script" --help 2>&1 | grep -q -i "usage\|help\|命令"; then
            echo "  ✅ $(basename "$script") - 帮助信息正常"
        else
            echo "  ⚠️  $(basename "$script") - 无帮助信息"
        fi
    done
    
    info "测试完成"
}

# 主函数
main() {
    case "${1:-}" in
        check)
            check_project
            ;;
        backup)
            backup_config
            ;;
        restore)
            warn "恢复功能尚未实现"
            echo "请手动从 backups/ 目录恢复"
            ;;
        clean)
            clean_files
            ;;
        update)
            warn "更新功能尚未实现"
            echo "请手动更新脚本"
            ;;
        stats)
            show_stats
            ;;
        test)
            run_tests
            ;;
        --help|-h|help)
            show_help
            ;;
        "")
            show_help
            ;;
        *)
            error "未知命令: $1"
            show_help
            exit 1
            ;;
    esac
}

# 运行主函数
main "$@"
