#!/bin/bash
# 快速清理脚本

echo "⚡ 快速清理"
echo "=========="

# 统计清理前状态
before_size=$(du -sh . | cut -f1)
before_files=$(find . -type f | wc -l)

echo "清理前:"
echo "  目录大小: $before_size"
echo "  文件数量: $before_files"

# 清理备份文件（保留最近的一个）
echo -e "\n🧹 清理多余的备份文件..."
for script in solutions/*.sh; do
    if [ -f "$script" ]; then
        base_name=$(basename "$script" .sh)
        
        # 找出所有备份，按时间排序，保留最新的一个
        backups=$(find solutions/ -name "${base_name}.sh.backup*" -o \
                         -name "${base_name}.sh.before_update" -o \
                         -name "${base_name}.sh.bak" 2>/dev/null | sort)
        
        backup_count=$(echo "$backups" | grep -c "^")
        if [ $backup_count -gt 1 ]; then
            # 保留最新的，删除其他的
            echo "  $base_name.sh: 删除 $((backup_count - 1)) 个旧备份"
            echo "$backups" | tail -n +2 | xargs rm -f 2>/dev/null
        fi
    fi
done

# 清理临时文件
echo -e "\n🗑️  清理临时文件..."
find . -name "*.swp" -o -name "*~" -delete 2>/dev/null
swp_count=$?
if [ $swp_count -eq 0 ]; then
    echo "  清理完成"
fi

# 清理后状态
after_size=$(du -sh . | cut -f1)
after_files=$(find . -type f | wc -l)
freed_space=$(echo "$before_size - $after_size" | bc 2>/dev/null || echo "未知")

echo -e "\n✅ 清理完成"
echo "=========="
echo "清理后:"
echo "  目录大小: $after_size"
echo "  文件数量: $after_files"
echo "  释放空间: $freed_space"
echo ""
echo "📋 保留的文件结构:"
echo "  solutions/ 目录:"
ls solutions/*.sh 2>/dev/null | xargs -I{} basename {} | sort
echo ""
echo "  tools/ 目录:"
ls tools/*.sh 2>/dev/null | xargs -I{} basename {} | sort
