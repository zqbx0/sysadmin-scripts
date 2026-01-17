#!/bin/bash
# 版本验证脚本 v1.0.1

echo "🔍 版本验证 v1.0.1"
echo "=================="

# 显示项目信息
echo -e "\n📦 项目信息:"
if [ -f "VERSION" ]; then
    cat VERSION
else
    echo "  ❌ VERSION 文件不存在"
fi

# 检查目录结构
echo -e "\n📁 目录结构验证:"
echo "解决方案脚本: $(ls solutions/*.sh 2>/dev/null | wc -l) 个"
echo "工具脚本: $(ls tools/*.sh 2>/dev/null | wc -l) 个"

# 检查版本号
echo -e "\n🔄 版本号验证:"
matched_scripts=0
total_scripts=0
for script in solutions/*.sh; do
    [ -f "$script" ] || continue
    total_scripts=$((total_scripts + 1))

    # 多种方式查找版本号
    version=""

    # 方式1: 查找 vX.X.X 格式
    version=$(grep -o "v[0-9]\.[0-9]\.[0-9]" "$script" | head -1)

    # 方式2: 查找 # 版本: 格式
    if [ -z "$version" ]; then
        version=$(grep -i "# 版本:" "$script" | grep -o "v[0-9]\.[0-9]\.[0-9]" | head -1)
    fi

    # 方式3: 查找 # 版本 v 格式
    if [ -z "$version" ]; then
        version=$(grep -i "# 版本 v" "$script" | grep -o "v[0-9]\.[0-9]\.[0-9]" | head -1)
    fi

    if [ "$version" = "v1.0.1" ]; then
        echo "  ✅ $(basename $script): $version"
        matched_scripts=$((matched_scripts + 1))
    elif [ -n "$version" ]; then
        echo "  ❌ $(basename $script): 版本不匹配 ($version)"
    else
        echo "  ⚠️  $(basename $script): 未找到版本号"
    fi
done

# 检查公共库
echo -e "\n📦 公共库检查:"
if [ -d "lib" ]; then
    lib_count=$(find lib -name "*.sh" -type f 2>/dev/null | wc -l)
    echo "  ✅ lib/ 目录存在 ($lib_count 个库文件)"
    echo "  ℹ️  没有 lib/ 目录"
fi

# 检查脚本是否使用公共库
echo -e "\n🔗 公共库使用情况:"
scripts_with_lib=0
total_scripts_all=0
for script in solutions/*.sh tools/*.sh; do
    [ -f "$script" ] || continue
    total_scripts_all=$((total_scripts_all + 1))
    if grep -q "source.*lib/" "$script" 2>/dev/null; then
        scripts_with_lib=$((scripts_with_lib + 1))
    fi
done
echo "  使用公共库的脚本: $scripts_with_lib/$total_scripts_all"

# 功能测试
echo -e "\n🧪 功能测试:"
echo -n "  proxy.sh 可执行: "
[ -x "proxy.sh" ] && echo "✅" || echo "❌"

echo -n "  Makefile 构建: "
[ -f "Makefile" ] && echo "✅" || echo "❌"

# 版本匹配率
echo -e "\n📈 版本匹配率:"
if [ $total_scripts -gt 0 ]; then
    match_rate=$((matched_scripts * 100 / total_scripts))
    echo "  $match_rate% ($matched_scripts/$total_scripts)"
else
    echo "  0% (0/0)"
fi

# 结果摘要
echo -e "\n🎉 v1.0.1 版本验证完成"
echo "📋 结果摘要:"
echo "  项目版本: v1.0.1"
echo "  解决方案脚本: $total_scripts 个"
echo "  版本匹配: $matched_scripts/$total_scripts"

echo -e "\n✅ 验证完成"
