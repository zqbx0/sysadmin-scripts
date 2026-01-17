#!/bin/bash
# 快速查看项目结构

echo "📁 项目快速概览"
echo "=============="

# 简洁显示
echo "核心目录:"
echo "  📂 solutions/    ($(ls solutions/*.sh 2>/dev/null | wc -l) 个脚本)"
echo "  📂 tools/        ($(ls tools/*.sh 2>/dev/null | wc -l) 个工具)"
echo "  📂 lib/          ($(ls lib/*.sh 2>/dev/null | wc -l) 个库)"
echo "  📂 docs/         ($(ls docs/*.md 2>/dev/null | wc -l) 个文档)"
echo "  📂 tests/        ($(ls tests/*.sh 2>/dev/null | wc -l) 个测试)"

echo -e "\n核心文件:"
ls -1 proxy.sh check_version.sh quick-start.sh maintain.sh VERSION README.md CHANGELOG.md Makefile 2>/dev/null | \
    while read file; do
        size=$(du -h "$file" 2>/dev/null | cut -f1 || echo "?")
        echo "  📄 $file ($size)"
    done

echo -e "\n📊 统计:"
echo "  总大小: $(du -sh . | cut -f1)"
echo "  文件数: $(find . -type f | grep -v ".git" | wc -l)"
echo "  目录数: $(find . -type d | grep -v ".git" | wc -l)"

echo -e "\n🔍 最近更新:"
find . -type f -name "*.sh" -exec stat -c "%y %n" {} + 2>/dev/null | \
    sort -rn | head -3 | \
    while read line; do
        date=$(echo "$line" | cut -d' ' -f1)
        file=$(echo "$line" | cut -d' ' -f4-)
        echo "  $date - $(basename "$file")"
    done
