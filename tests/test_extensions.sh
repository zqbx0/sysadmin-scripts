#!/bin/bash
source lib/common.sh
source lib/extensions.sh

echo "测试扩展函数:"
echo -n "  warning() 测试: "
warning "这是一个警告" >/dev/null && echo "✅"

echo -n "  hint() 测试: "
hint "这是一个提示" >/dev/null && echo "✅"

echo -n "  generate_uuid_compat() 测试: "
uuid=$(generate_uuid_compat)
[ ${#uuid} -eq 36 ] && echo "✅ ($uuid)" || echo "❌"

echo -n "  check_system_info() 测试: "
check_system_info >/dev/null && echo "✅"

echo -n "  download_file() 测试 (模拟): "
if type download_file >/dev/null 2>&1; then
    echo "✅ 函数存在"
else
    echo "❌ 函数不存在"
fi
