---
name: team-builder
description: >
  Manage OpenClaw agent teams — add agents, deploy templates, health check,
  auto-fix, view org tree, rollback. Use when user mentions: team management,
  add agent, org chart, health check, deploy solo template, rollback.
  Triggers: "加个助手", "新增 Agent", "看看团队", "组织架构", "体检",
  "修复", "回退", "超级个体", "team builder", "add agent".
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
