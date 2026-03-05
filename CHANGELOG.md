# Changelog

## [3.2.0] - 2026-03-06

### Added
- 版本兼容性检查：启动时自动检测 OpenClaw 版本，低于 2026.3.0 时警告并终止
- JSON 模式下版本不兼容输出结构化错误信息

## [3.1.0] - 2026-03-05

### Added
- ClawhHub Skill 标准适配：SKILL.md + 目录结构
- CLI 双模式：TUI（人类交互）+ CLI（AI Agent 批处理）
- `--json` 全局标志：所有查询命令输出纯 JSON
- `--yes` 全局标志：所有操作命令跳过确认
- `--add` 批处理模式：全参数化 Agent 创建
- `--solo` 批处理模式：无交互部署超级个体模板
- `--templates [--json]`：列出可用角色模板
- `draw_tree_json()`：JSON 格式组织架构输出
- `list_templates_json()`：JSON 格式模板列表
- CLI 参数解析器：支持 18 个参数
- SKILL.md 自然语言触发词文档

### Fixed
- `--tree --json` 输出被 init_hierarchy 文本污染
- `--fix --json` 内部 checkup 产生双重 JSON 输出
- `--status` Agent 计数显示格式问题

## [3.0.0] - 2026-03-04

### Added
- v3 完整重写：合并 v1 TUI + v2 层级管理
- 7 大功能模块：新增、超级个体、架构图、体检、修复、状态、回退
- team-hierarchy.json 层级元数据系统
- 9 个角色模板（行政/财务/人力/客服/运营/法务/内容/数据/技术）
- SOUL.md 自动生成（基于角色描述 + 层级关系）
- 自动备份/回退机制（最多保留 5 个备份）
- agentToAgent 全量 allow list 自动管理
- 6 项健康检查 + 一键修复

### Fixed
- `preflight()` 在 `set -e` 下的 `&& exit 1` 问题
- `init_hierarchy` 未读取 main 的 IDENTITY.md
- `agentToAgent` allow list 未包含所有已有 Agent
