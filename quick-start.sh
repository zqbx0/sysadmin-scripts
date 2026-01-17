#!/bin/bash
# 快速启动

echo "🚀 代理脚本快速启动"
echo "=================="

if [ ! -d "lib" ]; then
    echo "❌ 公共库不存在，请先运行重构脚本"
    exit 1
fi

# 选择脚本
echo "可用脚本:"
ls solutions/*.sh 2>/dev/null | xargs -n1 basename | sed 's/\.sh$//' | nl

read -p "选择脚本编号: " choice

scripts=($(ls solutions/*.sh 2>/dev/null))
if [ -n "${scripts[$((choice-1))]}" ]; then
    script="${scripts[$((choice-1))]}"
    echo "启动: $(basename "$script")"
    echo "--------------------------------"
    bash "$script" --help
else
    echo "❌ 无效选择"
fi
