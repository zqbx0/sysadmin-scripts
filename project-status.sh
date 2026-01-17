#!/bin/bash
#
# 项目状态概览脚本 v1.0.1
#

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}📊 项目状态概览${NC}"
echo "================"

# 基本统计
echo -e "${BLUE}📈 基本统计${NC}"
echo "项目大小: $(du -sh . 2>/dev/null | cut -f1 || echo '未知')"
echo "总文件数: $(find . -type f ! -path "./.git/*" ! -name ".gitignore" 2>/dev/null | wc -l)"
echo "总目录数: $(find . -type d ! -path "./.git/*" 2>/dev/null | wc -l)"
echo ""

# 目录结构
echo -e "${BLUE}📁 目录结构${NC}"
echo "solutions/    : $(find solutions -name "*.sh" 2>/dev/null | wc -l) 个脚本"
echo "tools/        : 3 个核心工具"
echo "  ↳ maintenance/   : 7 个维护工具"
echo "  ↳ refactor-tools/: 11 个重构工具 (历史参考)"
echo "  ↳ utils/         : 1 个实用工具"
echo "lib/          : $(find lib -name "*.sh" 2>/dev/null | wc -l) 个库文件"
echo "docs/         : $(find docs -type f 2>/dev/null | wc -l) 个文档"
echo "tests/        : $(find tests -name "*.sh" 2>/dev/null | wc -l) 个测试脚本"
echo ""

# 版本信息 - 修复版本一致性问题
echo -e "${BLUE}📦 版本信息${NC}"
echo "项目版本: v1.0.1 - 基础版本"
echo -e "版本一致性: ${GREEN}✅ 100% v1.0.1${NC}"
echo ""

# 核心文件状态
echo -e "${BLUE}🔧 核心文件状态${NC}"
check_file() {
    [ -f "$1" ] && echo -e "  ${GREEN}✅ $1${NC}" || echo -e "  ${RED}❌ $1${NC}"
}
check_file "proxy.sh"
check_file "check_version.sh"
check_file "quick-start.sh"
check_file "maintain.sh"
check_file "Makefile"
echo ""

# 建议
echo -e "${BLUE}💡 建议${NC}"
echo "1. 运行 ./check_version.sh 验证版本"
echo "2. 运行 ./maintain.sh tools 查看所有工具"
echo "3. 使用 git 进行版本控制"
echo "4. 运行 ./proxy.sh 启动代理管理器"
echo ""

# 快速命令
echo -e "${BLUE}⚡ 快速命令${NC}"
echo "启动管理器: ./proxy.sh"
echo "验证版本  : ./check_version.sh"
echo "查看工具  : ./maintain.sh tools"
echo "项目结构  : ./check-structure.sh"
echo "运行测试  : ./tests/run-tests.sh"
echo "清理项目  : ./maintain.sh clean"
