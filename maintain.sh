#!/bin/bash
# 项目维护脚本 v1.0.1

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 配置
PROJECT_NAME="sysadmin-scripts"
VERSION="v1.0.1"

show_header() {
    echo -e "${BLUE}🔧 $PROJECT_NAME 维护工具 $VERSION${NC}"
    echo "======================================"
}

show_help() {
    show_header
    echo ""
    echo -e "${YELLOW}用法: ./maintain.sh {command}${NC}"
    echo ""
    echo -e "${GREEN}项目管理:${NC}"
    echo "  status    - 显示项目状态"
    echo "  stats     - 详细统计信息"
    echo "  verify    - 完整性验证"
    echo "  test      - 运行测试"
    echo ""
    echo -e "${GREEN}维护操作:${NC}"
    echo "  clean     - 清理临时文件"
    echo "  backup    - 创建备份"
    echo "  audit     - 代码审计"
    echo ""
    echo -e "${GREEN}构建部署:${NC}"
    echo "  build     - 构建项目"
    echo "  package   - 打包发布"
    echo ""
    echo -e "${GREEN}工具集:${NC}"
    echo "  tools     - 列出所有工具"
    echo "  docs      - 生成文档"
    echo "  version   - 版本管理"
    echo ""
    echo -e "${YELLOW}示例:${NC}"
    echo "  ./maintain.sh status"
    echo "  ./maintain.sh clean"
    echo "  ./maintain.sh build"
}

check_health() {
    echo -e "${BLUE}🏥 项目健康检查${NC}"
    echo "-----------------"
    
    checks=0
    passed=0
    
    # 检查1: 核心目录
    ((checks++))
    if [ -d "solutions" ] && [ -d "tools" ] && [ -d "lib" ]; then
        echo -e "  ${GREEN}✅ 目录结构${NC}"
        ((passed++))
    else
        echo -e "  ${RED}❌ 目录结构${NC}"
    fi
    
    # 检查2: 版本文件
    ((checks++))
    if [ -f "VERSION" ]; then
        echo -e "  ${GREEN}✅ 版本文件${NC}"
        ((passed++))
    else
        echo -e "  ${RED}❌ 版本文件${NC}"
    fi
    
    # 检查3: 脚本语法
    ((checks++))
    bad_scripts=0
    total_scripts=0
    for script in solutions/*.sh tools/*.sh; do
        [ -f "$script" ] || continue
        ((total_scripts++))
        if ! bash -n "$script" 2>/dev/null; then
            ((bad_scripts++))
        fi
    done
    
    if [ $bad_scripts -eq 0 ]; then
        echo -e "  ${GREEN}✅ 脚本语法 ($total_scripts 个脚本)${NC}"
        ((passed++))
    else
        echo -e "  ${RED}❌ 脚本语法 ($bad_scripts/$total_scripts 错误)${NC}"
    fi
    
    # 健康度评分
    health_score=$((passed * 100 / checks))
    echo ""
    echo -e "${BLUE}📊 健康度: $health_score% ($passed/$checks)${NC}"
    
    if [ $health_score -ge 80 ]; then
        echo -e "${GREEN}🎉 项目状态良好${NC}"
    elif [ $health_score -ge 60 ]; then
        echo -e "${YELLOW}⚠️  项目状态一般${NC}"
    else
        echo -e "${RED}🚨 项目状态不佳${NC}"
    fi
}

show_stats() {
    show_header
    echo ""
    
    # 基本统计
    echo -e "${BLUE}📊 基本统计${NC}"
    echo "总大小: $(du -sh . | cut -f1)"
    echo "文件总数: $(find . -type f | grep -v ".git" | wc -l)"
    echo "目录总数: $(find . -type d | grep -v ".git" | wc -l)"
    
    # 脚本统计
    echo -e "\n${BLUE}📝 脚本统计${NC}"
    echo "解决方案脚本: $(find solutions/ -name "*.sh" | wc -l) 个"
    echo "工具脚本: $(find tools/ -name "*.sh" | wc -l) 个"
    echo "公共库: $(find lib/ -name "*.sh" | wc -l) 个"
    
    # 大小分布
    echo -e "\n${BLUE}📈 大小分布${NC}"
    echo "前5大文件:"
    find . -type f -exec du -h {} + 2>/dev/null | sort -rh | head -5 | \
        while read size file; do
            echo "  $size - $(basename $file)"
        done
    
    # 最近修改
    echo -e "\n${BLUE}🕐 最近修改${NC}"
    find . -type f -name "*.sh" -exec stat -c "%y %n" {} + 2>/dev/null | \
        sort -rn | head -3 | while read line; do
            date=$(echo $line | cut -d' ' -f1)
            file=$(echo $line | cut -d' ' -f4-)
            echo "  $date - $(basename $file)"
        done
}

run_tests() {
    echo -e "${BLUE}🧪 运行测试${NC}"
    echo "-------------"
    
    # 语法测试
    echo "1. 语法测试:"
    for script in solutions/*.sh; do
        if bash -n "$script" 2>/dev/null; then
            echo -e "  ${GREEN}✅ $(basename $script)${NC}"
        else
            echo -e "  ${RED}❌ $(basename $script)${NC}"
        fi
    done
    
    # 构建测试
    echo -e "\n2. 构建测试:"
    if [ -f "Makefile" ]; then
        if make build 2>/dev/null; then
            echo -e "  ${GREEN}✅ 构建通过${NC}"
        else
            echo -e "  ${RED}❌ 构建失败${NC}"
        fi
    else
        echo -e "  ${YELLOW}⚠️  无 Makefile${NC}"
    fi
    
    # 功能测试
    echo -e "\n3. 功能测试:"
    if [ -x "proxy.sh" ]; then
        echo -e "  ${GREEN}✅ proxy.sh 可执行${NC}"
    else
        echo -e "  ${RED}❌ proxy.sh 不可执行${NC}"
    fi
}

create_backup() {
    local backup_dir="backups/$(date +%Y%m%d_%H%M%S)"
    echo -e "${BLUE}📦 创建备份: $backup_dir${NC}"
    
    mkdir -p "$backup_dir"
    
    # 备份核心文件
    cp -r solutions/ tools/ lib/ "$backup_dir/"
    cp VERSION CHANGELOG.md README.md "$backup_dir/" 2>/dev/null
    
    # 创建备份信息
    cat > "$backup_dir/BACKUP_INFO.txt" << INFO
备份时间: $(date)
项目版本: $(head -1 VERSION)
备份内容:
  - solutions/ ($(ls solutions/*.sh | wc -l) 个脚本)
  - tools/ ($(ls tools/*.sh | wc -l) 个工具)
  - lib/ ($(ls lib/*.sh | wc -l) 个库文件)
备份大小: $(du -sh "$backup_dir" | cut -f1)
INFO
    
    echo -e "${GREEN}✅ 备份完成${NC}"
    echo "位置: $backup_dir"
    echo "大小: $(du -sh "$backup_dir" | cut -f1)"
}

code_audit() {
    echo -e "${BLUE}🔍 代码审计${NC}"
    echo "------------"
    
    # 检查安全问题
    echo "1. 安全检查:"
    dangerous_patterns=("rm -rf /" "chmod 777" "password.*=" "secret.*=")
    for pattern in "${dangerous_patterns[@]}"; do
        matches=$(grep -r "$pattern" solutions/ tools/ 2>/dev/null | wc -l)
        if [ $matches -gt 0 ]; then
            echo -e "  ${RED}⚠️  发现 $matches 处 '$pattern'${NC}"
        else
            echo -e "  ${GREEN}✅ 无 '$pattern'${NC}"
        fi
    done
    
    # 检查语法问题
    echo -e "\n2. 语法检查:"
    for script in solutions/*.sh tools/*.sh; do
        if shellcheck "$script" 2>/dev/null; then
            echo -e "  ${GREEN}✅ $(basename $script)${NC}"
        elif command -v shellcheck >/dev/null 2>&1; then
            echo -e "  ${YELLOW}⚠️  $(basename $script) 有警告${NC}"
        else
            echo -e "  ${YELLOW}⚠️  shellcheck 未安装${NC}"
            break
        fi
    done
    
    # 检查权限
    echo -e "\n3. 权限检查:"
    for script in solutions/*.sh tools/*.sh; do
        if [ -x "$script" ]; then
            echo -e "  ${GREEN}✅ $(basename $script) 可执行${NC}"
        else
            echo -e "  ${YELLOW}⚠️  $(basename $script) 不可执行${NC}"
        fi
    done
}

# 主程序
case "$1" in
    status|health)
        check_health
        ;;
    stats)
        show_stats
        ;;
    verify)
        ./check_version.sh
        ;;
    test)
        run_tests
        ;;
    clean)
        echo -e "${BLUE}🧹 清理临时文件${NC}"
        find . -name "*.swp" -o -name "*~" -o -name "*.tmp" -o -name "*.temp" -delete 2>/dev/null
        echo -e "${GREEN}✅ 清理完成${NC}"
        ;;
    backup)
        create_backup
        ;;
    audit)
        code_audit
        ;;
    build)
        echo -e "${BLUE}🔨 构建项目${NC}"
        [ -f "Makefile" ] && make build || echo "⚠️  无 Makefile"
        ;;
    package)
        echo -e "${BLUE}📦 打包发布${NC}"
        echo "功能开发中..."
        ;;
    tools)
        show_header
        echo ""
        echo -e "${GREEN}🛠️  可用工具:${NC}"
        echo ""
        echo -e "${BLUE}核心工具:${NC}"
        echo "  ./proxy.sh          - 统一管理器"
        echo "  ./check_version.sh  - 版本验证"
        echo "  ./quick-start.sh    - 快速启动"
        echo "  tools/version-manager.sh - 版本管理"
        echo ""
        echo -e "${BLUE}维护工具:${NC}"
        find tools/maintenance/ -name "*.sh" 2>/dev/null | sort | while read tool; do
            echo "  $tool"
        done
        ;;
    docs)
        echo -e "${BLUE}📚 生成文档${NC}"
        echo "功能开发中..."
        ;;
    version)
        tools/version-manager.sh "${@:2}"
        ;;
    help|--help|-h|"")
        show_help
        ;;
    *)
        echo -e "${RED}❌ 未知命令: $1${NC}"
        echo ""
        show_help
        ;;
esac
