# Makefile for Proxy Scripts

.PHONY: all build test clean deploy docs

# 变量
SCRIPTS := $(wildcard solutions/*.sh) $(wildcard tools/*.sh)
LIBS := $(wildcard lib/*.sh)

# 默认目标
all: test

# 构建 - 检查所有脚本语法
build:
	@echo "🔨 构建检查..."
	@for script in $(SCRIPTS) $(LIBS); do \
		echo -n "检查 $$script: "; \
		if bash -n $$script; then \
			echo "✅"; \
		else \
			echo "❌"; \
			exit 1; \
		fi \
	done

# 测试
test: build
	@echo "🧪 运行测试..."
	@./verify-refactor.sh
	@echo "✅ 测试通过"

# 清理
clean:
	@echo "🧹 清理..."
	@find . -name "*.backup.*" -delete
	@find . -name "*.log" -delete
	@rm -rf __pycache__ *.pyc
	@echo "✅ 清理完成"

# 部署到系统
deploy: build
	@echo "🚀 部署..."
	@for script in $(SCRIPTS); do \
		name=$$(basename $$script .sh); \
		sudo install -m 755 $$script /usr/local/bin/$$name; \
		echo "已安装: /usr/local/bin/$$name"; \
	done
	@echo "✅ 部署完成"

# 生成文档
docs:
	@echo "📚 生成文档..."
	@echo "# 函数文档" > FUNCTIONS.md
	@echo "\n## 公共函数库 (lib/common.sh)" >> FUNCTIONS.md
	@grep "^[a-zA-Z_].*()" lib/common.sh | sed 's/() {/()/g' | sort >> FUNCTIONS.md
	@echo "\n## 脚本列表" >> FUNCTIONS.md
	@for script in $(SCRIPTS); do \
		echo "- $$(basename $$script): $$(head -1 $$script | sed 's/# //')" >> FUNCTIONS.md; \
	done
	@echo "✅ 文档已生成: FUNCTIONS.md"

# 代码统计
stats:
	@echo "📊 代码统计:"
	@echo "脚本数量: $$(find solutions/ tools/ -name "*.sh" | wc -l)"
	@echo "库文件数量: $$(find lib/ -name "*.sh" | wc -l)"
	@echo "总代码行数: $$(find . -name "*.sh" -exec cat {} \; | wc -l)"
	@echo "注释行数: $$(find . -name "*.sh" -exec grep -c "^#" {} \; | awk '{s+=$$1} END {print s}')"

# 帮助
help:
	@echo "可用命令:"
	@echo "  make build    - 语法检查"
	@echo "  make test     - 运行测试"
	@echo "  make clean    - 清理文件"
	@echo "  make deploy   - 部署到系统"
	@echo "  make docs     - 生成文档"
	@echo "  make stats    - 代码统计"
