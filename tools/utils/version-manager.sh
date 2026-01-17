#!/bin/bash
# 版本管理器 v1.0.1

VERSION_FILE="VERSION"
CHANGELOG_FILE="CHANGELOG.md"

show_version() {
    echo "📦 当前版本:"
    cat "$VERSION_FILE"
}

update_version() {
    echo "🔄 更新版本号..."
    read -p "新版本号 (如 v1.0.2): " new_version
    read -p "更新说明: " update_note
    
    # 备份当前版本
    cp "$VERSION_FILE" "${VERSION_FILE}.backup.$(date +%s)"
    
    # 更新 VERSION 文件
    sed -i "1s/.*/$new_version - $update_note/" "$VERSION_FILE"
    
    # 更新 CHANGELOG
    echo -e "\n## $new_version ($(date +%Y-%m-%d))\n- $update_note" >> "$CHANGELOG_FILE"
    
    echo "✅ 版本已更新到 $new_version"
}

sync_versions() {
    echo "🔗 同步所有脚本版本号..."
    
    # 从 VERSION 文件获取版本号
    version=$(head -1 "$VERSION_FILE" | cut -d' ' -f1)
    
    # 更新所有脚本
    find solutions/ tools/ lib/ -name "*.sh" -type f | while read script; do
        # 保留原文件头部格式，只更新版本号
        sed -i "s/# 版本:.*/# 版本: $version/" "$script"
        sed -i "s/# 版本 v.*/# 版本 $version/" "$script"
        sed -i "s/v[0-9]\.[0-9]\.[0-9]/$version/g" "$script"
        echo "  ✅ $(basename $script)"
    done
    
    echo "✅ 版本同步完成"
}

case "$1" in
    show)
        show_version
        ;;
    update)
        update_version
        ;;
    sync)
        sync_versions
        ;;
    *)
        echo "用法: $0 {show|update|sync}"
        echo "  show  - 显示当前版本"
        echo "  update - 更新版本号"
        echo "  sync  - 同步所有脚本版本"
        ;;
esac
