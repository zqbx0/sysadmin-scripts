#!/bin/bash
# 版本检查测试

echo "测试: 版本文件存在性"
if [ -f "VERSION" ]; then
    echo "✅ VERSION 文件存在"
else
    echo "❌ VERSION 文件不存在"
    exit 1
fi

echo "测试: 版本号格式"
version=$(head -1 VERSION | grep -o "v[0-9]\.[0-9]\.[0-9]")
if [ -n "$version" ]; then
    echo "✅ 版本号格式正确: $version"
else
    echo "❌ 版本号格式错误"
    exit 1
fi

echo "✅ 版本检查测试通过"
