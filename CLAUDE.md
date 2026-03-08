# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

OpenClaw Team Builder is a **ClawhHub Skill** — a single bash script (`scripts/team-builder.sh`) that adds team management capabilities to OpenClaw's multi-agent platform. It provides both a TUI (interactive menu for humans) and a CLI (parameterized commands for AI agents).

## Architecture

The entire codebase is one bash script (~800 lines) with embedded Python for JSON manipulation. Key architectural decisions:

- **Dual-mode design**: No args = TUI interactive menu; flags = CLI batch mode. The `$JSON_OUTPUT` and `$AUTO_YES` globals control output suppression and confirmation skipping.
- **Embedded Python**: All JSON read/write/transform logic uses inline `python3 << 'PYEOF'` heredocs, not jq. This is intentional — python3 is a required dependency, jq is not.
- **File-based state**: Team hierarchy lives in `~/.openclaw/team-hierarchy.json` (version 2 format). Backups go to `~/.openclaw/backups/` (max 5 retained).
- **OpenClaw CLI wrapper**: The script calls `openclaw agents add`, `openclaw agents bind`, `openclaw gateway restart` etc. Never bypass the script to call these directly — the script handles hierarchy sync, SOUL.md generation, backup, and channel auto-binding.

## Key Files

| File | Purpose |
|------|---------|
| `scripts/team-builder.sh` | The skill script — all logic lives here |
| `SKILL.md` | ClawhHub skill manifest + AI agent workflow docs (frontmatter metadata + usage instructions) |
| `.clawhub/lock.json` | ClawhHub dependency lock |

## Running & Testing

```bash
# Run TUI mode (requires openclaw CLI + python3 installed)
bash scripts/team-builder.sh

# Run CLI mode examples
bash scripts/team-builder.sh --tree --json
bash scripts/team-builder.sh --checkup --json
bash scripts/team-builder.sh --templates --json

# Test a dry-run add (will fail without openclaw installed)
bash scripts/team-builder.sh --add --id test --soul skip --yes
```

No build step, no tests, no linter. The script runs directly with `bash`.

## Conventions

- **System requirements**: OpenClaw >= 2026.3.0, python3, bash 3.2+ (macOS/Linux)
- **CLI flags**: All query commands support `--json`; all write commands support `--yes` to skip prompts
- **9 role templates**: `xingzheng`, `caiwu`, `hr`, `kefu`, `yunying`, `falv`, `neirong`, `shuju`, `jishu` — hardcoded in the script
- **6 scenario presets** for `--suggest`: ecommerce, content, devteam, startup, consulting, solo
- **SOUL.md generation**: `--soul auto` generates from role + hierarchy context; `--soul template:<key>` uses built-in template; `--soul skip` keeps defaults
- **Channel model**: Each agent can have its own bot per channel (Telegram/Discord/Feishu). Shared bots bind to one agent only. Creation auto-binds all enabled channels.
- **Backup/rollback**: Every write operation auto-backs up before executing. `--rollback --index N --yes` restores state.

## SKILL.md is the AI Agent Interface

`SKILL.md` frontmatter contains trigger words and metadata for ClawhHub skill discovery. The body documents the exact workflow AI agents should follow — especially the "collect all info in ONE message" pattern for `--add`. When modifying agent-facing behavior, update SKILL.md accordingly.
