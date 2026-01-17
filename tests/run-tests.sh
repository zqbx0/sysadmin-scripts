#!/bin/bash
# 测试运行器

echo "🧪 运行测试套件"
echo "================"

# 颜色
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

total_tests=0
passed_tests=0

run_test() {
    local test_file="$1"
    local test_name="$2"
    
    ((total_tests++))
    
    if bash -n "$test_file" 2>/dev/null && bash "$test_file" 2>/dev/null; then
        echo -e "  ${GREEN}✅ $test_name${NC}"
        ((passed_tests++))
        return 0
    else
        echo -e "  ${RED}❌ $test_name${NC}"
        return 1
    fi
}

# 单元测试
echo "1. 单元测试:"
for test in tests/unit/test_*.sh; do
    [ -f "$test" ] || continue
    run_test "$test" "$(basename "$test")"
done

# 集成测试
echo -e "\n2. 集成测试:"
for test in tests/integration/test_*.sh; do
    [ -f "$test" ] || continue
    run_test "$test" "$(basename "$test")"
done

# 结果
echo -e "\n📊 测试结果:"
echo "总计: $total_tests 个测试"
echo "通过: $passed_tests 个"
echo "失败: $((total_tests - passed_tests)) 个"

if [ $passed_tests -eq $total_tests ]; then
    echo -e "\n${GREEN}🎉 所有测试通过！${NC}"
    exit 0
else
    echo -e "\n${RED}❌ 有测试失败${NC}"
    exit 1
fi
