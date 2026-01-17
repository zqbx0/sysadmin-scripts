# 更新日志

## v1.0.2 (2025-01-16) - 重构版本
### 🚀 重大重构
- **创建公共函数库**: lib/common.sh, lib/extensions.sh, lib/argo.sh, lib/config.sh, lib/installer.sh
- **重构所有脚本**: solutions/ 目录下所有脚本现在使用公共函数
- **统一管理器**: 新增 proxy.sh 作为统一入口
- **代码复用**: 减少重复代码约60%
- **标准化**: 所有脚本添加标准帮助信息
- **测试套件**: 添加完整的测试脚本和 Makefile
- **文档**: 添加完整的 USAGE_GUIDE.md 和函数索引

### 📁 新目录结构
```
sysadmin-scripts/
├── proxy.sh              # 统一管理器
├── solutions/            # 8个代理方案脚本
├── tools/                # 工具脚本
├── lib/                  # 公共函数库 (5个文件)
├── examples/             # 使用示例
├── logs/                 # 日志目录
├── Makefile              # 构建工具
├── VERSION              # 版本信息
├── CHANGELOG.md         # 更新日志
├── USAGE_GUIDE.md       # 使用指南
└── README.md            # 项目说明
```

## v1.0.1 (2025-01-15) - 初始整合
- 收集和整理所有代理脚本到同一目录
- 创建基础目录结构
- 初步分类脚本功能

## v1.0.0 (2025-01-14) - 初始版本
- 从原作者仓库获取各个独立脚本
- 包含: sing-box.sh, sba.sh, argox.sh, hysteria2.sh 等
