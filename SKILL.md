---
name: openclaw-team-builder
description: >
  Manage OpenClaw agent teams — add agents, deploy templates, health check,
  auto-fix, view org tree, rollback, goal-driven team suggestion.
  Use when user mentions: team management, add agent, org chart, health check,
  deploy solo template, rollback, suggest team, recommend agents.
  Triggers: "加个助手", "新增 Agent", "看看团队", "组织架构", "体检",
  "修复", "回退", "超级个体", "推荐团队", "建议配置", "team builder",
  "add agent", "suggest team".
metadata: {"clawdbot":{"emoji":"🦞","os":["darwin","linux"],"requires":{"bins":["openclaw","python3"]}}}
---

# OpenClaw Team Builder

Manage your AI agent team: add agents to any position in the org tree, deploy templates, run health checks, auto-fix issues, and rollback changes.

## Setup

The script is at `~/.openclaw/skills/team-builder/scripts/team-builder.sh`. It requires `openclaw` CLI and `python3`.

```bash
TB="bash ~/.openclaw/skills/team-builder/scripts/team-builder.sh"
```

All examples below use `$TB` as shorthand.

## View Org Tree

```bash
# Human-readable tree
$TB --tree

# JSON output (for parsing)
$TB --tree --json
```

JSON output example:
```json
{
  "main": {"name":"软软","emoji":"😘","role":"director","reports_to":null,"manages":["xingzheng"],"description":""},
  "xingzheng": {"name":"xingzheng","emoji":"🤖","role":"worker","reports_to":"main","manages":[],"description":""}
}
```

## Add an Agent

```bash
# Full CLI mode (no prompts)
$TB --add \
  --id finance-lead \
  --name "小财-财务助手" \
  --emoji "💰" \
  --role "负责报销审核、预算管理、财务报表" \
  --parent main \
  --soul auto \
  --yes

# Use a built-in role template (auto-fills role description)
$TB --add \
  --id caiwu \
  --soul template:caiwu \
  --parent main \
  --yes

# With model override and feishu config
$TB --add \
  --id translator \
  --name "翻译官" \
  --emoji "🌐" \
  --role "负责中英文翻译" \
  --parent main \
  --model anthropic/claude-sonnet-4-6 \
  --feishu-app-id cli_xxx \
  --feishu-secret yyy \
  --yes
```

### Parameters

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| `--id` | Yes | - | Agent ID (english, kebab-case) |
| `--name` | No | same as id | Display name |
| `--emoji` | No | 🤖 | Agent emoji |
| `--role` | No | 通用AI助手 | Role description for SOUL.md |
| `--parent` | No | main | Parent agent ID in org tree |
| `--soul` | No | auto | `auto`, `template:<key>`, or `skip` |
| `--model` | No | inherit | Model override |
| `--feishu-app-id` | No | - | Feishu bot App ID |
| `--feishu-secret` | No | - | Feishu bot App Secret |
| `--yes` | No | false | Skip confirmation prompts |

### Soul modes

- `auto` — Generate SOUL.md from role description + org relationships
- `template:<key>` — Use built-in template (also sets name/emoji/role automatically)
- `skip` — Keep OpenClaw default template

## Goal-Driven Team Suggestion

Given a business goal, recommend the best team configuration from built-in templates.

```bash
# Get recommendation (human-readable)
$TB --suggest --goal "电商平台运营"

# JSON output (for AI Agent parsing)
$TB --suggest --goal "电商平台运营" --json
```

JSON output example:
```json
{
  "goal": "电商平台运营",
  "matched_scenario": "ecommerce",
  "scenario_name": "电商团队",
  "recommended_agents": [
    {"id": "kefu", "template": "kefu", "reason": "处理客户咨询和售后"},
    {"id": "yunying", "template": "yunying", "reason": "运营数据分析和活动策划"}
  ],
  "deploy_commands": ["$TB --add --id kefu --soul template:kefu --parent main --yes", "..."],
  "total_agents": 4
}
```

Supported scenarios: `ecommerce`(电商), `content`(内容创作), `devteam`(研发), `startup`(创业), `consulting`(专业服务), `solo`(超级个体).

### AI Agent Workflow: Creating a New Agent

When the user wants to add a new agent, follow these **exact steps** in order:

**Step 1: Interview** (ask these 4 questions, one at a time):

1. "这个 Agent 的核心任务是什么？（一句话描述，比如'负责市场分析和竞品研究'）"
2. "自主级别？• 建议（给方案，你来决定）• 执行（直接帮你搞定）• 全自动（完全不用管）"
3. "有什么禁止事项？（比如'不能删除文件'、'不能发外部消息'）"
4. "最后一问，语调风格？• 专业 • 亲切 • 简洁"

**Step 2: Construct and execute the command** (do NOT use `openclaw agents add` directly):

```bash
$TB --add \
  --id <kebab-case-id-from-name> \
  --name "<user's chosen name>" \
  --emoji "<appropriate emoji>" \
  --role "核心任务：<Q1答案>。自主级别：<Q2答案>。禁止事项：<Q3答案>。语调：<Q4答案>" \
  --parent main \
  --soul auto \
  --yes
```

The script will automatically: create agent, generate SOUL.md, configure agentToAgent, and **bind to ALL enabled channels** (Telegram, Discord, Feishu, etc.).

**Step 3: Confirm to user**:

"✅ <name> 已创建并加入团队！已自动绑定所有可用渠道（Telegram/飞书/Discord等）。用 `$TB --tree` 查看当前组织架构。"

**IMPORTANT**: Always use `$TB --add` (the script), never directly call `openclaw agents add`. The script handles binding, agentToAgent, hierarchy, and SOUL.md — raw CLI does not.

## Deploy Solo Template

Deploy the "Super Individual" team: 4 specialist agents under main (dev, design, content, data).

```bash
# Deploy with defaults
$TB --solo --yes

# Deploy with specific model
$TB --solo --model anthropic/claude-sonnet-4-6 --yes

# Skip SOUL generation
$TB --solo --soul skip --yes
```

Already-existing agent IDs are automatically skipped.

## List Role Templates

```bash
# Human-readable
$TB --templates

# JSON
$TB --templates --json
```

Available templates: `xingzheng`(行政), `caiwu`(财务), `hr`(人力), `kefu`(客服), `yunying`(运营), `falv`(法务), `neirong`(内容), `shuju`(数据), `jishu`(技术)

## Health Check

Scans for: gateway status, agentToAgent config, allow list completeness, SOUL.md presence, binding completeness, hierarchy file.

```bash
# Human-readable
$TB --checkup

# JSON
$TB --checkup --json
```

JSON output example:
```json
{
  "checks": [
    {"name": "gateway", "status": "ok", "detail": null},
    {"name": "a2a_allow", "status": "warn", "detail": "缺失: xingzheng"}
  ],
  "issues": 1
}
```

## Auto-Fix

Automatically fixes issues found by health check: restart gateway, enable agentToAgent, fill allow list, generate missing SOUL.md, add bindings, init hierarchy.

```bash
# Auto-fix (with confirmation)
$TB --fix

# Auto-fix (no prompts)
$TB --fix --yes
```

## Team Status

Full overview: org tree, agent list, a2a config, bindings, SOUL.md line counts, backup count.

```bash
# Human-readable
$TB --status

# JSON (comprehensive)
$TB --status --json
```

## Rollback

Every operation creates a backup. Rollback restores config, hierarchy, and SOUL.md files, and deletes agents created in that operation.

```bash
# Interactive rollback (pick from list)
$TB --rollback

# Rollback to most recent backup
$TB --rollback --index 1 --yes
```

## Workflow Examples

### "帮我加一个财务助手"

```bash
$TB --add --id caiwu --soul template:caiwu --parent main --yes
```

### "看看团队现在什么状态"

```bash
$TB --status --json
```

### "团队体检一下，有问题就修"

```bash
$TB --checkup --json
# If issues > 0:
$TB --fix --yes
```

### "刚才加错了，撤回"

```bash
$TB --rollback --index 1 --yes
```

## Notes

- All write operations auto-backup before executing (max 5 backups kept)
- Run `openclaw gateway restart` after changes to apply
- The script preserves existing agents — never overwrites
- TUI mode (no args) provides a full interactive menu for human use
