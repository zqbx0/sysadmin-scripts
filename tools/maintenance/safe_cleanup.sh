#!/bin/bash
# 安全清理脚本 - 保留每个脚本的最新备份

echo "🧹 安全清理开始"
echo "==============="

# 记录清理前状态
before_size=$(du -sh . | cut -f1)
before_count=$(find . -type f | wc -l)

echo "清理前:"
echo "  目录大小: $before_size"
echo "  文件总数: $before_count"

# 清理解决方案目录的备份
echo -e "\n📦 清理解决方案备份..."
cleaned_solution=0
for script in solutions/*.sh; do
    if [ -f "$script" ]; then
        base_name=$(basename "$script" .sh)
        
        # 找出该脚本的所有备份
        backups=$(find solutions/ -name "${base_name}.sh.backup*" -o \
                             -name "${base_name}.sh.before_update" -o \
                             -name "${base_name}.sh.bak" 2>/dev/null)
        
        # 如果没有备份，跳过
        if [ -z "$backups" ]; then
            continue
        fi
        
        # 按修改时间排序，最新的在前
        sorted_backups=$(echo "$backups" | xargs -I{} sh -c 'echo "$(stat -c %Y "{}") {}"' | \
                        sort -rn | cut -d' ' -f2-)
        
        # 保留最新的一个，删除其他的
        keep=$(echo "$sorted_backups" | head -1)
        to_delete=$(echo "$sorted_backups" | tail -n +2)
        
        delete_count=$(echo "$to_delete" | grep -c "^")
        if [ $delete_count -gt 0 ]; then
            echo "  📝 $base_name.sh: 保留最新备份，删除 $delete_count 个旧备份"
            echo "$to_delete" | while read file; do
                if [ -n "$file" ]; then
                    rm -f "$file"
                    cleaned_solution=$((cleaned_solution + 1))
                fi
            done
        fi
    fi
done

# 清理工具目录的备份
echo -e "\n🔧 清理工具脚本备份..."
cleaned_tools=0
for script in tools/*.sh; do
    if [ -f "$script" ]; then
        base_name=$(basename "$script" .sh)
        
        backups=$(find tools/ -name "${base_name}.sh.backup*" -o \
                         -name "${base_name}.sh.before_update" 2>/dev/null)
        
        if [ -z "$backups" ]; then
            continue
        fi
        
        sorted_backups=$(echo "$backups" | xargs -I{} sh -c 'echo "$(stat -c %Y "{}") {}"' | \
                        sort -rn | cut -d' ' -f2-)
        
        keep=$(echo "$sorted_backups" | head -1)
        to_delete=$(echo "$sorted_backups" | tail -n +2)
        
        delete_count=$(echo "$to_delete" | grep -c "^")
        if [ $delete_count -gt 0 ]; then
            echo "  📝 $base_name.sh: 保留最新备份，删除 $delete_count 个旧备份"
            echo "$to_delete" | while read file; do
                if [ -n "$file" ]; then
                    rm -f "$file"
                    cleaned_tools=$((cleaned_tools + 1))
                fi
            done
        fi
    fi
done

# 清理空目录
echo -e "\n📂 清理空目录..."
cleaned_dirs=0
find . -type d -empty 2>/dev/null | grep -v "^\.$" | grep -v ".git" | while read dir; do
    echo "  删除空目录: $dir"
    rmdir "$dir" 2>/dev/null && cleaned_dirs=$((cleaned_dirs + 1))
done

# 记录清理后状态
after_size=$(du -sh . | cut -f1)
after_count=$(find . -type f | wc -l)
total_cleaned=$((cleaned_solution + cleaned_tools))

echo -e "\n✅ 清理完成"
echo "==============="
echo "清理统计:"
echo "  解决方案备份: 删除 $cleaned_solution 个文件"
echo "  工具脚本备份: 删除 $cleaned_tools 个文件"
echo "  空目录: 删除 $cleaned_dirs 个"
echo "  总计清理: $total_cleaned 个文件"

echo -e "\n📊 空间变化:"
echo "  清理前: $before_size ($before_count 个文件)"
echo "  清理后: $after_size ($after_count 个文件)"

# 显示当前目录结构
echo -e "\n📁 当前目录结构:"
echo "solutions/ 目录:"
ls -lh solutions/*.sh 2>/dev/null | awk '{print "  " $9 " (" $5 ")"}'

echo -e "\ntools/ 目录:"
ls -lh tools/*.sh 2>/dev/null | awk '{print "  " $9 " (" $5 ")"}'

echo -e "\nlib/ 目录:"
ls -lh lib/*.sh 2>/dev/null | awk '{print "  " $9 " (" $5 ")"}'

# 显示剩余的备份文件
remaining_backups=$(find . -name "*.backup*" -o -name "*.bak" -o -name "*.before_update" 2>/dev/null | wc -l)
echo -e "\n📋 剩余备份文件: $remaining_backups 个"
if [ $remaining_backups -gt 0 ]; then
    echo "保留的备份文件:"
    find . -name "*.backup*" -o -name "*.bak" -o -name "*.before_update" 2>/dev/null | \
        xargs -I{} basename {} | sort | uniq | while read file; do
        echo "  📄 $file"
    done
fi
