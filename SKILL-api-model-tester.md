---
name: api-model-tester
description: >
  Test OpenAI-compatible API endpoints and manage model configuration. Discover available models,
  diagnose auth issues, add new providers, and configure OpenClaw defaults.
  Use when user mentions: model config, api test, model test, add provider, diagnose model,
  provider auth, api health check, model availability.
  Triggers: "模型配置", "API测试", "白嫖", "添加模型", "诊断模型", "model config",
  "api test", "selftest", "diagnose", "test api", "add provider", "configure models".
metadata: {"clawdbot":{"emoji":"🚀","os":["darwin","linux"],"requires":{"bins":["openclaw","python3","curl"]}}}
---

# OpenClaw API Model Tester

Test OpenAI-compatible API endpoints, discover available models, diagnose authentication issues, and configure OpenClaw defaults.

## Setup

The script is at `~/.openclaw/skills/team-builder/scripts/api-model-tester.sh`. It requires `openclaw` CLI, `python3`, and `curl`.

```bash
TESTER="bash ~/.openclaw/skills/team-builder/scripts/api-model-tester.sh"
```

All examples below use `$TESTER` as shorthand.

## Quick Health Check

Run a health check on current model configuration (1-2 seconds):

```bash
# Human-readable output
$TESTER --selftest

# JSON output (for parsing)
$TESTER --selftest --json
```

JSON output example:
```json
{
  "verified_date": "2026-03-08",
  "script_version": "1.0.0",
  "providers": [
    {"name": "EdgeFN / 白山智算", "url": "https://api.edgefn.net/v1", "status": "reachable", "http_code": 200, "latency_ms": 342, "error": ""},
    {"name": "AIGCBest (中转)", "url": "https://api2.aigcbest.top/v1", "status": "unreachable", "http_code": 0, "latency_ms": 0, "error": "Connection failed"}
  ],
  "summary": {"total": 9, "reachable": 8, "unreachable": 1, "confidence_pct": 88}
}
```

## View Current Configuration

Overview of all providers, models, auth status, and default settings:

```bash
# Human-readable
$TESTER --status

# JSON output
$TESTER --status --json
```

JSON output example:
```json
{
  "openclaw_version": "2026.3.2",
  "default_model": "anthropic/claude-sonnet-4-6",
  "fallback_count": 1271,
  "fallbacks_top10": ["anthropic/claude-opus-4-6", "dashscope/qwen-max", "groq/llama-3.3-70b-versatile"],
  "providers": [
    {"name": "openrouter", "model_count": 235, "auth_type": "env", "auth_detail": "sk-or-v1..."},
    {"name": "dashscope", "model_count": 207, "auth_type": "models.json", "auth_detail": "sk-b37a..."},
    {"name": "edgefn", "model_count": 21, "auth_type": "models.json", "auth_detail": "sk-sSTH..."}
  ],
  "total_models": 1273
}
```

## Diagnose Issues

Find authentication errors, expired tokens, failed profiles, and cleanup recommendations:

```bash
# Human-readable diagnostics
$TESTER --diagnose

# JSON output (for parsing)
$TESTER --diagnose --json
```

JSON output example:
```json
{
  "info": [
    "默认模型: deepseek-v3",
    "Fallback: qwen-max, claude-3-5-sonnet"
  ],
  "issues": [
    "EXPIRED: prof_old — OAuth 已过期 3天前",
    "AUTH_FAIL: prof_bad — 5次认证失败 (401/403)"
  ],
  "warnings": [
    "EXPIRING: prof_xyz — 将在 2小时后过期",
    "RATE_LIMIT: prof_abc — 3次限流"
  ],
  "cleanup_candidates": ["prof_old", "prof_bad"],
  "healthy": false
}
```

## Add a Provider (Interactive Wizard)

Step-by-step wizard to add a new API provider:

```bash
# Interactive mode (prompts for all inputs)
$TESTER --wizard
```

The wizard will:
1. Show 9 built-in providers (5 domestic + 4 global)
2. Ask you to select or enter custom URL
3. Request API key
4. Test connectivity and list available models
5. Write config to OpenClaw
6. Set as default (optional)

### Built-in Providers

#### Domestic China (5 providers)

| Provider | URL | Models | Free Credits |
|----------|-----|--------|--------------|
| EdgeFN / 白山智算 | `https://api.edgefn.net/v1` | GLM-5, DeepSeek-V3.2, Qwen3, Kimi | 150元 + 300元 + 邀请200元/人 |
| SiliconFlow (硅基) | `https://api.siliconflow.cn/v1` | 100+ 国产模型 | 2000万Token永久免费 |
| AIGCBest (中转) | `https://api2.aigcbest.top/v1` | GPT 系列 | 注册即可使用 |
| 阿里云百炼 (DashScope) | `https://dashscope.aliyuncs.com/compatible-mode/v1` | Qwen3.5, DeepSeek, GLM, Kimi | 每模型100万Token + 7000万Token/90天 |
| 火山引擎方舟 (字节) | `https://ark.cn-beijing.volces.com/api/v3` | 豆包, Qwen, DeepSeek, Kimi, GLM | 每天200万Token + 每模型50万 |

#### Global (4 providers)

| Provider | URL | Models | Free Credits |
|----------|-----|--------|--------------|
| Groq | `https://api.groq.com/openai/v1` | Llama, Qwen, Gemma | 永久免费 30-60 RPM |
| NVIDIA NIM | `https://integrate.api.nvidia.com/v1` | 187+ 模型 | 免费 Key, ~40 RPM |
| Cerebras | `https://api.cerebras.ai/v1` | Llama, Qwen 大模型 | 100万Token/天 |
| OpenRouter | `https://openrouter.ai/api/v1` | 全球模型聚合, 24+ 免费 | free 模型完全免费 |

## Manage API Keys

View, update, or add API keys for providers (stored in environment variables):

```bash
# Interactive key management
$TESTER --manage-keys
```

The menu allows:
- View all provider keys
- Replace an existing key
- Add a new key
- Test connectivity with new key

## Factory Reset

Restore all model configuration to factory defaults (auto-backups first):

```bash
# Restore defaults with confirmation
$TESTER --factory-reset

# Auto-confirm
$TESTER --factory-reset --yes
```

## Backup Configuration

Backup all OpenClaw config files (openclaw.json, auth-profiles, shell profile, gateway plist):

```bash
# Interactive backup
$TESTER --backup

# JSON output
$TESTER --backup --json
```

Keeps last 10 backups in `~/.openclaw/backups/`. Restore with `--rollback`.

## CLI Flags Reference

### Output & Confirmation

| Flag | Purpose |
|------|---------|
| `--json` | JSON output (for AI agent parsing) |
| `--yes` | Skip all confirmation prompts |

### Modes

| Mode | Purpose |
|------|---------|
| (no args) | Interactive main menu (default, recommended) |
| `--wizard` | Step-by-step provider setup |
| `--selftest --json` | Quick health check (1-2 seconds) |
| `--status --json` | Current config overview |
| `--diagnose --json` | Find auth issues and problems |
| `--manage-keys` | View/update provider keys |
| `--view-config` | Display full configuration |
| `--backup` | Backup all config files |
| `--factory-reset` | Restore defaults |

## AI Agent Workflow: Adding a New Provider

When the user wants to add a model provider, follow these **exact steps** in order.

**CRITICAL: Collect ALL info in ONE message. Do NOT use multi-step Q&A — session context may be lost between messages.**

**Step 1: Ask ONE compound question** (all in a single message):

"好的！帮你配置新的模型提供商，请一次性告诉我：
1️⃣ 选择提供商（国内：EdgeFN/硅基/百炼/方舟/AIGCBest，全球：Groq/OpenRouter/Cerebras/NVIDIA）或自定义URL
2️⃣ API Key（从对应平台获取）
3️⃣ 是否设为默认模型？

比如：'EdgeFN，sk_xxx..., 设为默认'"

If the user gives a short answer (e.g. "硅基流动"), infer reasonable defaults:
- provider: SiliconFlow  key: (ask for it)  set_default: y

If the user gives partial info, ask only for missing credentials, then proceed.

**Step 2: Immediately construct and execute**:

```bash
$TESTER --wizard
# (or if you have key, use non-interactive mode)
```

If you have the API key and provider details, you can test directly:
```bash
$TESTER <base_url> <api_key> --setup --yes
```

**Step 3: Confirm to user** (in the SAME response as execution):

"✅ 提供商已添加！已探测到X个可用模型。"

Then show config:
```bash
$TESTER --status --json
```

**Step 4: Set defaults** (in the SAME response):

"🎯 当前默认模型: <default_model>

要改成其他模型吗？（比如：deepseek-v3, qwen-max 等）
或者跳过，保持当前设置。"

If user specifies a model:
```bash
# Would require additional command (check script for set-default mode)
```

**IMPORTANT**:
- Always use `$TESTER --wizard` for interactive setup, or `$TESTER <url> <key> --setup --yes` for non-interactive
- Collect API key and provider name in ONE message before executing
- After adding provider, always show `--status --json` to confirm discovery
- Always offer to set default model after addition
- Never use `openclaw models add` directly — use the tester script

## Supported API Format

Only OpenAI-compatible APIs are supported:
- Endpoint: `/v1/chat/completions` (Chat Completions API)
- Request body: `{"model": "...", "messages": [...]}`
- Response: Standard OpenAI format with `choices[].message.content`

### Compatible Services

- OpenAI API and drop-in replacements
- OpenAI API proxies (中转站)
- All 9 built-in providers
- Any service with `/v1/models` and `/v1/chat/completions` endpoints

### NOT Supported

- Anthropic native API (Claude uses different format)
- Google Gemini native API
- Other non-OpenAI-compatible formats

## Workflow Examples

### "帮我测一下模型能不能用"

```bash
$TESTER --selftest --json
# Returns confidence_pct, total_models, health status
```

### "我想加个国产模型"

```bash
$TESTER --wizard
# (Choose EdgeFN or SiliconFlow, enter API key)
```

### "看看现在配了哪些模型"

```bash
$TESTER --status --json
```

### "有个 Token 过期了，帮我诊断"

```bash
$TESTER --diagnose --json
# Shows expired_profiles, auth failures, cleanup candidates
```

### "帮我备份一下配置"

```bash
$TESTER --backup --json
# Returns backup path and file list
```

## Notes

- All write operations auto-backup before executing
- Health check (`--selftest`) takes 1-2 seconds
- Config discovery and testing may take 10-30 seconds depending on provider response time
- API keys are stored in environment variables (not in config files)
- Backup/rollback available via the script (`--backup`, `--rollback`)
