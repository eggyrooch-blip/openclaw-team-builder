#!/bin/bash
# ============================================================================
# API Model Tester & OpenClaw 模型配置向导
# ============================================================================
#
# 支持的 API 格式:
#   仅支持 OpenAI Chat Completions 兼容格式 (/v1/chat/completions)
#   即：请求体为 {"model": "...", "messages": [...]} 格式的 API
#
# 兼容的服务商 (已测试):
#   - 中转站: edgefn.net, aigcbest.top 等 OpenAI API 中转
#   - SiliconFlow (硅基流动)
#   - OpenRouter
#   - 任何提供 /v1/models + /v1/chat/completions 端点的服务
#
# 不支持:
#   - Anthropic 原生 API (非 OpenAI 格式)
#   - Google Gemini 原生 API
#   - 其他非 OpenAI 兼容格式的 API
#
# 用法:
#   交互式向导 (推荐):  bash api-model-tester.sh
#   快速探测:           bash api-model-tester.sh <base_url> <api_key>
#   探测+测试:          bash api-model-tester.sh <base_url> <api_key> --test
#   详细模式:           bash api-model-tester.sh <base_url> <api_key> --verbose
#   探测+配置 OpenClaw: bash api-model-tester.sh <base_url> <api_key> --setup
#   完整向导:           bash api-model-tester.sh --wizard
# ============================================================================

set -u

# --- 版本 & 全局控制 ---
SCRIPT_VERSION="1.0.0"
JSON_OUTPUT=false
AUTO_YES=false

# --- 颜色 ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# --- 预设服务商 ---
declare -a PROVIDER_NAMES=()
declare -a PROVIDER_URLS=()
declare -a PROVIDER_DESCS=()
declare -a PROVIDER_REFERRALS=()
declare -a PROVIDER_FREE_INFO=()

add_provider() {
    PROVIDER_NAMES+=("$1")
    PROVIDER_URLS+=("$2")
    PROVIDER_DESCS+=("$3")
    PROVIDER_REFERRALS+=("$4")
    PROVIDER_FREE_INFO+=("$5")
}

# --- 国内平台 (直连无障碍) ---
add_provider "EdgeFN / 白山智算 (钱多多)" \
    "https://api.edgefn.net/v1" \
    "GLM-5/DeepSeek-V3.2/Qwen3/Kimi 等顶级国产模型" \
    "https://ai.baishan.com/auth/login?referralCode=5pxJMMOcLa" \
    "注册送150元 + 首次调用送300元 + 邀请送200元/人"

add_provider "SiliconFlow (硅基流动)" \
    "https://api.siliconflow.cn/v1" \
    "100+ 国产模型，延迟低" \
    "https://cloud.siliconflow.cn/i/ljXTcot9" \
    "注册送2000万Token，9B以下模型永久免费"

add_provider "AIGCBest (中转)" \
    "https://api2.aigcbest.top/v1" \
    "GPT 系列中转" \
    "https://api2.aigcbest.top/register?aff=Jdcp" \
    "注册即可使用"

add_provider "阿里云百炼 (DashScope)" \
    "https://dashscope.aliyuncs.com/compatible-mode/v1" \
    "Qwen3.5/DeepSeek/GLM/Kimi，官方OpenClaw支持" \
    "https://bailian.console.aliyun.com" \
    "新用户每模型100万Token + 推广期送7000万Token，有效期90天"

add_provider "火山引擎方舟 (字节)" \
    "https://ark.cn-beijing.volces.com/api/v3" \
    "豆包+Qwen/DeepSeek/Kimi/GLM全系" \
    "https://console.volcengine.com/ark" \
    "每天自动发放200万Token (永久循环) + 新用户每模型50万"

# --- 全球平台 ---
add_provider "Groq" \
    "https://api.groq.com/openai/v1" \
    "Llama/Qwen/Gemma，推理极快" \
    "https://console.groq.com/" \
    "永久免费 30-60 RPM，每天约1000次请求"

add_provider "NVIDIA NIM" \
    "https://integrate.api.nvidia.com/v1" \
    "187+ 模型 (DeepSeek/Llama/Gemma/Qwen)，部分国内不可达" \
    "https://build.nvidia.com/settings/api-keys" \
    "免费 API Key，约40 RPM，无需充值"

add_provider "Cerebras" \
    "https://api.cerebras.ai/v1" \
    "Llama/Qwen 大模型，速度极快" \
    "https://console.cerebras.ai/" \
    "每天100万Token免费"

add_provider "OpenRouter" \
    "https://openrouter.ai/api/v1" \
    "全球模型聚合，24+ 免费模型" \
    "https://openrouter.ai/keys" \
    "free 模型完全免费，加:free后缀使用"

add_provider "自定义 URL" "" "手动输入 API 地址" "" ""

# --- 辅助函数 ---
print_header() {
    echo ""
    echo -e "${BOLD}========================================${NC}"
    echo -e "${BOLD} $1${NC}"
    echo -e "${BOLD}========================================${NC}"
    echo ""
}

print_step() {
    echo -e "${BOLD}${CYAN}[$1]${NC} ${BOLD}$2${NC}"
}

prompt_choice() {
    local prompt="$1" default="$2"
    printf "${prompt} [${default}]: " >&2
    read -r _choice
    echo "${_choice:-$default}"
}

prompt_yn() {
    local prompt="$1" default="${2:-y}"
    if [ "$AUTO_YES" = true ]; then
        return 0
    fi
    if [ "$default" = "y" ]; then
        printf "${prompt} [Y/n]: " >&2
    else
        printf "${prompt} [y/N]: " >&2
    fi
    read -r _yn
    _yn="${_yn:-$default}"
    [[ "$_yn" =~ ^[Yy] ]]
}

print_curl_cmd() {
    local method="$1" url="$2" data="${3:-}"
    local masked_key="${API_KEY:0:8}...${API_KEY: -4}"
    echo ""
    echo -e "${DIM}━━━ REQUEST ━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    if [ -n "$data" ]; then
        echo -e "${CYAN}curl -X ${method} '${url}' \\${NC}"
        echo -e "${CYAN}  -H 'Authorization: Bearer ${masked_key}' \\${NC}"
        echo -e "${CYAN}  -H 'Content-Type: application/json' \\${NC}"
        echo -e "${CYAN}  -d '${data}'${NC}"
    else
        echo -e "${CYAN}curl -X ${method} '${url}' \\${NC}"
        echo -e "${CYAN}  -H 'Authorization: Bearer ${masked_key}' \\${NC}"
        echo -e "${CYAN}  -H 'Content-Type: application/json'${NC}"
    fi
}

print_response() {
    local http_code="$1" body="$2" elapsed="${3:-}"
    echo -e "${DIM}━━━ RESPONSE ━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    if [ -n "$elapsed" ]; then
        echo -e " ${YELLOW}HTTP ${http_code}${NC}  ${DIM}(${elapsed})${NC}"
    else
        echo -e " ${YELLOW}HTTP ${http_code}${NC}"
    fi
    echo "$body" | python3 -m json.tool 2>/dev/null || echo "$body"
    echo -e "${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

normalize_base_url() {
    local url="$1"
    url="${url%/}"
    url="${url%/chat/completions}"
    if [[ ! "$url" =~ /v[0-9]+$ ]]; then
        url="${url}/v1"
    fi
    echo "$url"
}

# --- 临时文件清理 ---
_TMPFILES=()
_cleanup_tmp() { rm -f ${_TMPFILES[@]+"${_TMPFILES[@]}"} 2>/dev/null; }
trap _cleanup_tmp EXIT INT TERM

# --- OpenClaw 本地执行辅助 ---
oc_exec() {
    bash -c "$*" 2>&1
}

# --- 安全: 清洁用户输入 (模型名/provider名/路径) ---
sanitize_input() {
    # 移除可能导致 shell 注入的字符: ; | & ` $ ( ) { } < > ! \n
    local val="$1"
    val="${val//\'/}"
    val="${val//\"/}"
    val="${val//\;/}"
    val="${val//\|/}"
    val="${val//\&/}"
    val="${val//\`/}"
    val="${val//\$/}"
    val="${val//\(/}"
    val="${val//\)/}"
    val="${val//\{/}"
    val="${val//\}/}"
    val="${val//\</}"
    val="${val//\>/}"
    val="${val//\!/}"
    echo "$val"
}

# --- Shell Profile 检测 (支持 zsh/bash) ---
detect_shell_profile() {
    if [ "$(basename "$SHELL" 2>/dev/null)" = "zsh" ]; then
        echo "$HOME/.zshrc"
    elif [ -f "$HOME/.zshrc" ]; then
        echo "$HOME/.zshrc"
    else
        echo "$HOME/.bashrc"
    fi
}

# --- Gateway plist 环境变量注入 (macOS LaunchAgent) ---
inject_plist_env_vars() {
    # 从 shell profile 读取 _API_KEY 变量，注入到 gateway plist
    local inject_script
    inject_script=$(cat << 'PYEOF'
import plistlib, os, re

plist_path = os.path.expanduser("~/Library/LaunchAgents/ai.openclaw.gateway.plist")
if not os.path.exists(plist_path):
    print("SKIP:no plist")
    exit(0)

# 检测 shell profile
shell = os.path.basename(os.environ.get("SHELL", "bash"))
if shell == "zsh" or os.path.exists(os.path.expanduser("~/.zshrc")):
    profile = os.path.expanduser("~/.zshrc")
else:
    profile = os.path.expanduser("~/.bashrc")

if not os.path.exists(profile):
    print("SKIP:no profile")
    exit(0)

# 从 profile 提取 _API_KEY 变量
env_vars = {}
with open(profile) as f:
    for line in f:
        line = line.strip()
        if line.startswith("export ") and "_API_KEY=" in line:
            parts = line[7:].split("=", 1)
            if len(parts) == 2:
                key = parts[0].strip()
                val = parts[1].strip().strip('"').strip("'")
                env_vars[key] = val

if not env_vars:
    print("SKIP:no keys")
    exit(0)

# 注入 plist
with open(plist_path, "rb") as f:
    plist = plistlib.load(f)

env_dict = plist.get("EnvironmentVariables", {})
env_dict.update(env_vars)
plist["EnvironmentVariables"] = env_dict

with open(plist_path, "wb") as f:
    plistlib.dump(plist, f)

print(f"OK:{len(env_vars)}")
PYEOF
)
    local result
    result=$(python3 -c "$inject_script" 2>&1)

    if [[ "$result" == OK:* ]]; then
        local count="${result#OK:}"
        echo -e "  ${GREEN}已注入 ${count} 个 API Key 到 gateway plist${NC}"
    elif [[ "$result" == SKIP:* ]]; then
        : # 静默跳过 (非 macOS 或无 key)
    else
        echo -e "  ${YELLOW}plist 注入跳过: ${result}${NC}"
    fi
}

# --- Gateway 安全重启 (stop + inject + install) ---
restart_gateway() {
    echo -n "  停止 gateway... "
    oc_exec "openclaw gateway stop" >/dev/null 2>&1
    echo -e "${GREEN}OK${NC}"
    sleep 2
    echo -n "  启动 gateway... "
    oc_exec "openclaw gateway install --force" >/dev/null 2>&1
    echo -e "${GREEN}OK${NC}"
    # macOS: 注入环境变量到 plist 并重新加载
    inject_plist_env_vars
    # 重新加载 LaunchAgent
    local uid
    uid=$(id -u)
    launchctl bootout "gui/${uid}" ~/Library/LaunchAgents/ai.openclaw.gateway.plist 2>/dev/null
    sleep 1
    launchctl bootstrap "gui/${uid}" ~/Library/LaunchAgents/ai.openclaw.gateway.plist 2>/dev/null
}

# --- 连接 OpenClaw 辅助 (多处复用) ---
setup_openclaw_connection() {
    # 加载 shell profile 中的环境变量 (API Key 等)
    local _prof
    _prof=$(detect_shell_profile)
    [ -f "$_prof" ] && source "$_prof" 2>/dev/null

    echo -n "  检测 OpenClaw... "
    OC_VERSION=$(oc_exec "openclaw --version" 2>/dev/null | head -1)
    if [ -z "$OC_VERSION" ]; then
        echo -e "${RED}未找到 openclaw 命令${NC}"
        return 1
    fi
    echo -e "${GREEN}${OC_VERSION}${NC}"
    echo ""
    return 0
}

# --- 独立功能: 设置默认模型 & Fallback ---
run_set_default() {
    print_header "设置默认模型 & Fallback"

    setup_openclaw_connection || return 1

    # 获取当前状态
    OC_STATUS=$(oc_exec "openclaw models status --json")
    CURRENT_DEFAULT=$(echo "$OC_STATUS" | python3 -c "import json,sys; print(json.loads(sys.stdin.read()).get('defaultModel',''))" 2>/dev/null)
    CURRENT_FALLBACKS=$(echo "$OC_STATUS" | python3 -c "import json,sys; print(', '.join(json.loads(sys.stdin.read()).get('fallbacks',[])))" 2>/dev/null)

    echo -e "  当前默认模型: ${CYAN}${CURRENT_DEFAULT:-未设置}${NC}"
    if [ -n "$CURRENT_FALLBACKS" ]; then
        echo -e "  当前 fallback: ${DIM}${CURRENT_FALLBACKS}${NC}"
    fi
    echo ""

    # 获取所有可用模型
    VERIFY_JSON=$(oc_exec "openclaw models list --all --json")
    ALL_AVAILABLE=$(echo "$VERIFY_JSON" | python3 -c "
import json,sys
d=json.loads(sys.stdin.read())
for m in sorted(d.get('models',[]), key=lambda x: x.get('key','')):
    print(m['key'])
" 2>/dev/null)

    AVAIL_COUNT=$(echo "$ALL_AVAILABLE" | sed '/^$/d' | wc -l | tr -d ' ')
    echo -e "  可用模型总数: ${GREEN}${AVAIL_COUNT}${NC}"
    echo ""

    if [ "$AVAIL_COUNT" -eq 0 ]; then
        echo -e "${YELLOW}没有可用模型，请先配置 provider${NC}"
        return 1
    fi

    # 按 provider 分组显示
    echo -e "${BOLD}可用模型:${NC}"
    AVAIL_ARRAY=()
    IDX=0
    echo "$ALL_AVAILABLE" | python3 -c "
import sys
from collections import defaultdict
groups = defaultdict(list)
idx = 0
for line in sys.stdin:
    line = line.strip()
    if not line: continue
    prov = line.split('/')[0] if '/' in line else 'default'
    groups[prov].append((idx, line))
    idx += 1

for prov in sorted(groups.keys()):
    print(f'  --- {prov} ({len(groups[prov])}) ---')
    for i, m in groups[prov]:
        print(f'  {i+1:4d}) {m}')
" 2>/dev/null
    while IFS= read -r m; do
        [ -n "$m" ] && AVAIL_ARRAY+=("$m")
    done <<< "$ALL_AVAILABLE"
    echo ""

    # 设置默认模型
    if prompt_yn "是否更改默认模型?"; then
        printf "输入编号或模型全名: "
        read -r DEFAULT_INPUT

        if [[ "$DEFAULT_INPUT" =~ ^[0-9]+$ ]]; then
            idx=$((DEFAULT_INPUT - 1))
            if [ "$idx" -ge 0 ] && [ "$idx" -lt "${#AVAIL_ARRAY[@]}" ]; then
                NEW_DEFAULT="${AVAIL_ARRAY[$idx]}"
            else
                echo -e "${RED}编号超出范围${NC}"
                NEW_DEFAULT=""
            fi
        else
            NEW_DEFAULT="$DEFAULT_INPUT"
        fi

        if [ -n "$NEW_DEFAULT" ]; then
            echo -n "  设置默认模型为 ${NEW_DEFAULT}... "
            SET_RESULT=$(oc_exec "openclaw models set '$(sanitize_input "${NEW_DEFAULT}")'")
            if echo "$SET_RESULT" | grep -qi "error\|fail"; then
                echo -e "${RED}失败${NC}"
                echo "  $SET_RESULT"
            else
                echo -e "${GREEN}OK${NC}"
            fi
        fi
    fi
    echo ""

    # 配置 Fallback
    if prompt_yn "是否配置 fallback 列表?"; then
        echo ""
        OC_STATUS_NEW=$(oc_exec "openclaw models status --json")
        NEW_DEFAULT=$(echo "$OC_STATUS_NEW" | python3 -c "import json,sys; print(json.loads(sys.stdin.read()).get('defaultModel',''))" 2>/dev/null)

        # 构建非默认模型列表
        FB_ARRAY=()
        while IFS= read -r m; do
            [ -n "$m" ] || continue
            if [ "$m" = "$NEW_DEFAULT" ]; then continue; fi
            FB_ARRAY+=("$m")
        done <<< "$ALL_AVAILABLE"

        echo -e "  除默认模型外共 ${GREEN}${#FB_ARRAY[@]}${NC} 个模型可作为 fallback"
        echo ""
        echo -e "  ${CYAN}1)${NC} ${BOLD}全部设为 fallback${NC} ${GREEN}(推荐)${NC}"
        echo -e "     ${DIM}默认模型失败时自动切换到其他任意可用模型${NC}"
        echo -e "  ${CYAN}2)${NC} ${BOLD}手动选择${NC}"
        echo -e "     ${DIM}按编号指定 fallback 优先级顺序${NC}"
        echo ""
        FB_MODE=$(prompt_choice "请选择" "1")

        echo -n "  清除旧 fallback... "
        oc_exec "openclaw models fallbacks clear" >/dev/null 2>&1
        echo -e "${GREEN}OK${NC}"

        if [ "$FB_MODE" = "1" ]; then
            # 全部设为 fallback
            local fb_ok=0 fb_fail=0
            echo -n "  添加 ${#FB_ARRAY[@]} 个 fallback 模型..."
            for fb_model in "${FB_ARRAY[@]}"; do
                ADD_RESULT=$(oc_exec "openclaw models fallbacks add '$(sanitize_input "${fb_model}")'" 2>&1)
                if echo "$ADD_RESULT" | grep -qi "error\|fail"; then
                    fb_fail=$((fb_fail + 1))
                else
                    fb_ok=$((fb_ok + 1))
                fi
            done
            echo ""
            echo -e "  ${GREEN}成功 ${fb_ok}${NC} / ${RED}失败 ${fb_fail}${NC}"
        else
            # 手动选择
            echo ""
            echo "可用模型 (输入编号，按优先级排序，逗号分隔):"
            echo ""
            local fb_idx=0
            for m in "${FB_ARRAY[@]}"; do
                fb_idx=$((fb_idx + 1))
                printf "  %3d) %s\n" "$fb_idx" "$m"
            done
            echo ""
            printf "Fallback 顺序 (如 1,3,5,2): "
            read -r FB_SELECTIONS

            if [ -n "$FB_SELECTIONS" ]; then
                for sel in $(echo "$FB_SELECTIONS" | tr ',' ' '); do
                    idx=$((sel - 1))
                    if [ "$idx" -ge 0 ] && [ "$idx" -lt "${#FB_ARRAY[@]}" ]; then
                        fb_model="${FB_ARRAY[$idx]}"
                        echo -n "  添加 fallback: ${fb_model}... "
                        ADD_RESULT=$(oc_exec "openclaw models fallbacks add '$(sanitize_input "${fb_model}")'")
                        if echo "$ADD_RESULT" | grep -qi "error\|fail"; then
                            echo -e "${RED}失败${NC}"
                        else
                            echo -e "${GREEN}OK${NC}"
                        fi
                    fi
                done
            fi
        fi
    fi
    echo ""

    # 最终状态
    FINAL_STATUS=$(oc_exec "openclaw models status --json")
    echo -e "${BOLD}最终状态:${NC}"
    echo "$FINAL_STATUS" | python3 -c "
import json, sys
d = json.loads(sys.stdin.read())
print(f'  默认模型:  {d.get(\"defaultModel\", \"未设置\")}')
fb = d.get('fallbacks', [])
if fb:
    print(f'  Fallback ({len(fb)}):')
    for i, m in enumerate(fb, 1):
        print(f'    {i}. {m}')
else:
    print('  Fallback:  无')
" 2>/dev/null
    echo ""

    if prompt_yn "是否重启 Gateway 使配置生效?"; then
        restart_gateway
    fi
    echo ""
}

# --- 独立功能: 回退配置 ---
run_rollback() {
    print_header "回退 OpenClaw 配置"

    setup_openclaw_connection || return 1

    # 查找备份文件
    echo -e "${BOLD}可用备份:${NC}"
    BACKUPS=$(oc_exec "ls -lt ~/.openclaw/openclaw.json.bak-* ~/.openclaw/openclaw.json.pre-* 2>/dev/null | head -10")
    if [ -z "$BACKUPS" ]; then
        echo -e "  ${YELLOW}没有找到备份文件${NC}"
        return 1
    fi

    echo "$BACKUPS" | cat -n
    echo ""
    printf "选择要恢复的备份编号 (或输入 q 取消): "
    read -r ROLLBACK_CHOICE

    if [ "$ROLLBACK_CHOICE" = "q" ] || [ -z "$ROLLBACK_CHOICE" ]; then
        echo "已取消"
        return 0
    fi

    BACKUP_FILE=$(echo "$BACKUPS" | sed -n "${ROLLBACK_CHOICE}p" | awk '{print $NF}')
    if [ -z "$BACKUP_FILE" ]; then
        echo -e "${RED}无效选择${NC}"
        return 1
    fi

    echo -e "  将恢复: ${CYAN}${BACKUP_FILE}${NC}"
    if prompt_yn "确认恢复? (当前配置将备份为 .bak-rollback)"; then
        ROLL_RESULT=$(oc_exec "cp ~/.openclaw/openclaw.json ~/.openclaw/openclaw.json.bak-rollback && cp '${BACKUP_FILE}' ~/.openclaw/openclaw.json && echo OK")
        if echo "$ROLL_RESULT" | grep -q "OK"; then
            echo -e "  ${GREEN}恢复成功${NC}"
            echo ""
            if prompt_yn "是否重启 Gateway?"; then
                restart_gateway
            fi
        else
            echo -e "  ${RED}恢复失败: ${ROLL_RESULT}${NC}"
        fi
    fi
    echo ""
}

# --- 独立功能: Provider 可达性自检 ---
run_selftest() {
    local verified_date
    verified_date=$(date +%Y-%m-%d)
    local total=0 reachable=0 unreachable=0
    local _results_file
    _results_file=$(mktemp); _TMPFILES+=("$_results_file")

    # 遍历预设 provider（跳过最后一个"自定义 URL"）
    local provider_count=${#PROVIDER_NAMES[@]}
    local last_idx=$((provider_count - 1))

    if [ "$JSON_OUTPUT" != true ]; then
        print_header "Provider 可达性检测"
        echo -e "  ${DIM}检测日期: ${verified_date} | 脚本版本: ${SCRIPT_VERSION}${NC}"
        echo ""
    fi

    for i in $(seq 0 $((last_idx - 1))); do
        local name="${PROVIDER_NAMES[$i]}"
        local url="${PROVIDER_URLS[$i]}"

        # 跳过空 URL
        if [ -z "$url" ]; then continue; fi

        total=$((total + 1))
        local status="unreachable" http_code="000" latency_ms="0" error=""

        # curl 检测 /models 端点
        local curl_result
        curl_result=$(curl -s -o /dev/null -w "%{http_code}\n%{time_total}" \
            --connect-timeout 5 --max-time 10 \
            "${url}/models" 2>&1)

        http_code=$(echo "$curl_result" | head -1)
        local time_total
        time_total=$(echo "$curl_result" | tail -1)

        if [ -n "$time_total" ] && [ "$http_code" != "000" ]; then
            latency_ms=$(python3 -c "print(int(float('${time_total}') * 1000))" 2>/dev/null || echo 0)
            # 200/401/403/405 均视为可达（服务在线）
            case "$http_code" in
                200|401|403|405|422)
                    status="reachable"
                    reachable=$((reachable + 1))
                    ;;
                *)
                    status="degraded"
                    error="HTTP ${http_code}"
                    reachable=$((reachable + 1))  # 仍然可达，只是非标准响应
                    ;;
            esac
        else
            unreachable=$((unreachable + 1))
            if echo "$curl_result" | grep -qi "resolve"; then
                error="DNS resolution failed"
            elif echo "$curl_result" | grep -qi "timed out\|timeout"; then
                error="Connection timeout"
            elif echo "$curl_result" | grep -qi "refused"; then
                error="Connection refused"
            else
                error="Connection failed"
            fi
        fi

        # 记录结果到临时文件（TSV 格式）
        echo -e "${name}\t${url}\t${status}\t${http_code}\t${latency_ms}\t${error}" >> "$_results_file"

        # TUI 输出
        if [ "$JSON_OUTPUT" != true ]; then
            if [ "$status" = "reachable" ]; then
                printf "  ${GREEN}✓${NC} %-20s %4dms  (%s)\n" "$name" "$latency_ms" "$http_code"
            elif [ "$status" = "degraded" ]; then
                printf "  ${YELLOW}~${NC} %-20s %4dms  (%s)\n" "$name" "$latency_ms" "$error"
            else
                printf "  ${RED}✗${NC} %-20s  ---   %s\n" "$name" "$error"
            fi
        fi
    done

    # 置信度
    local confidence=0
    if [ "$total" -gt 0 ]; then
        confidence=$((reachable * 100 / total))
    fi

    if [ "$JSON_OUTPUT" = true ]; then
        RESULTS_FILE="$_results_file" VERIFIED_DATE="$verified_date" \
        SCRIPT_VER="$SCRIPT_VERSION" TOTAL="$total" REACHABLE="$reachable" \
        UNREACHABLE="$unreachable" CONFIDENCE="$confidence" python3 << 'PYEOF'
import json, os

results = []
with open(os.environ["RESULTS_FILE"]) as f:
    for line in f:
        parts = line.strip().split("\t")
        if len(parts) >= 6:
            results.append({
                "name": parts[0],
                "url": parts[1],
                "status": parts[2],
                "http_code": int(parts[3]) if parts[3] != "000" else 0,
                "latency_ms": int(parts[4]),
                "error": parts[5]
            })

output = {
    "verified_date": os.environ["VERIFIED_DATE"],
    "script_version": os.environ["SCRIPT_VER"],
    "providers": results,
    "summary": {
        "total": int(os.environ["TOTAL"]),
        "reachable": int(os.environ["REACHABLE"]),
        "unreachable": int(os.environ["UNREACHABLE"]),
        "confidence_pct": int(os.environ["CONFIDENCE"])
    }
}
print(json.dumps(output, indent=2, ensure_ascii=False))
PYEOF
    else
        echo ""
        echo -e "  ─────────────────────────────────"
        echo -e "  可达 ${GREEN}${reachable}${NC}/${total} — 置信度: ${BOLD}${confidence}%${NC}"
        echo ""
    fi
}

# --- 独立功能: 配置状态 JSON 输出 ---
run_status_json() {
    # 非交互，仅本机，直接输出 JSON
    local _prof
    _prof=$(detect_shell_profile)
    [ -f "$_prof" ] && source "$_prof" 2>/dev/null

    local oc_ver
    oc_ver=$(openclaw --version 2>/dev/null | head -1)
    if [ -z "$oc_ver" ]; then
        echo '{"error": "openclaw not found"}'
        return 1
    fi

    local oc_status oc_models
    oc_status=$(openclaw models status --json 2>/dev/null)
    oc_models=$(openclaw models list --all --json 2>/dev/null)

    OC_STATUS="$oc_status" OC_MODELS="$oc_models" OC_VER="$oc_ver" python3 << 'PYEOF'
import json, os

oc_ver = os.environ.get("OC_VER", "")
try:
    status = json.loads(os.environ.get("OC_STATUS", "{}"))
except:
    status = {}
try:
    models_data = json.loads(os.environ.get("OC_MODELS", "{}"))
except:
    models_data = {}

models_list = models_data.get("models", [])
providers = {}
for m in models_list:
    p = m.get("key", "").split("/")[0]
    providers[p] = providers.get(p, 0) + 1

# 认证信息
auth_info = []
for ap in status.get("auth", {}).get("providers", []):
    eff = ap.get("effective", {})
    auth_info.append({
        "name": ap.get("provider", ""),
        "model_count": providers.get(ap.get("provider", ""), 0),
        "auth_type": eff.get("kind", "none"),
        "auth_detail": eff.get("detail", "")
    })

# 补充没有 auth 信息但有模型的 provider
auth_names = {a["name"] for a in auth_info}
for p, count in sorted(providers.items(), key=lambda x: -x[1]):
    if p not in auth_names:
        auth_info.append({"name": p, "model_count": count, "auth_type": "builtin", "auth_detail": ""})

output = {
    "openclaw_version": oc_ver,
    "default_model": status.get("defaultModel", ""),
    "fallback_count": len(status.get("fallbacks", [])),
    "fallbacks_top10": status.get("fallbacks", [])[:10],
    "providers": sorted(auth_info, key=lambda x: -x["model_count"]),
    "total_models": len(models_list)
}
print(json.dumps(output, indent=2, ensure_ascii=False))
PYEOF
}

# --- 独立功能: 查看当前配置 ---
run_view_config() {
    print_header "OpenClaw 配置概览"

    setup_openclaw_connection || return 1

    # 获取模型状态
    echo -n "  读取配置..."
    OC_STATUS=$(oc_exec "openclaw models status --json" 2>/dev/null)
    OC_MODELS=$(oc_exec "openclaw models list --all --json" 2>/dev/null)
    echo -e " ${GREEN}OK${NC}"
    echo ""

    # 用 python 汇总输出
    _VIEW_SCRIPT=$(mktemp); _TMPFILES+=("$_VIEW_SCRIPT")
    cat > "$_VIEW_SCRIPT" << 'PYEOF'
import json, sys, os

status_raw = os.environ.get("OC_STATUS", "{}")
models_raw = os.environ.get("OC_MODELS", "{}")

try:
    status = json.loads(status_raw)
except:
    status = {}
try:
    models_data = json.loads(models_raw)
except:
    models_data = {}

# 基本信息
config_path = status.get("configPath", "未知")
default_model = status.get("defaultModel", "未设置")
fallbacks = status.get("fallbacks", [])
allowed = status.get("allowed", [])

print(f"  配置文件:   {config_path}")
print(f"  默认模型:   {default_model}")
print(f"  Fallback:   {len(fallbacks)} 个")
if fallbacks:
    for i, fb in enumerate(fallbacks[:10], 1):
        print(f"    {i:3d}. {fb}")
    if len(fallbacks) > 10:
        print(f"    ... 及其他 {len(fallbacks)-10} 个")
print(f"  Allowed:    {len(allowed)} 个" + (" (未限制)" if not allowed else ""))
print()

# Provider 概览
models_list = models_data.get("models", [])
providers = {}
for m in models_list:
    p = m.get("key", "").split("/")[0]
    providers[p] = providers.get(p, 0) + 1

print("  Provider 概览:")
print(f"  {'名称':20s} {'模型数':>6s}")
print(f"  {'─'*28}")
for p in sorted(providers, key=lambda x: providers[x], reverse=True):
    print(f"  {p:20s} {providers[p]:>6d}")
print(f"  {'─'*28}")
print(f"  {'合计':20s} {len(models_list):>6d}")
print()

# 认证信息
auth = status.get("auth", {})
auth_providers = auth.get("providers", [])
if auth_providers:
    print("  认证方式:")
    print(f"  {'Provider':20s} {'方式':12s} {'详情'}")
    print(f"  {'─'*60}")
    for ap in auth_providers:
        prov_name = ap.get("provider", "?")
        effective = status.get("auth", {}).get("providers", [])
        # find in top-level providers
        for tp in status.get("auth", {}).get("providers", []):
            if tp.get("provider") == prov_name:
                eff = tp.get("effective", {})
                kind = eff.get("kind", "未知")
                detail = eff.get("detail", "")
                # 简化显示
                if kind == "env":
                    kind_str = "环境变量"
                elif kind == "models.json":
                    kind_str = "配置文件"
                elif kind == "profiles":
                    kind_str = "OAuth/Token"
                else:
                    kind_str = kind
                print(f"  {prov_name:20s} {kind_str:12s} {detail[:40]}")
                break
    print()
    store_path = auth.get("storePath", "")
    if store_path:
        print(f"  认证存储:   {store_path}")
    print()

PYEOF

    OC_STATUS="$OC_STATUS" OC_MODELS="$OC_MODELS" python3 "$_VIEW_SCRIPT" 2>/dev/null
    rm -f "$_VIEW_SCRIPT"
    echo ""
}

# --- 独立功能: 还原默认配置 ---
run_factory_reset() {
    print_header "还原 OpenClaw 默认配置"

    setup_openclaw_connection || return 1

    echo -e "  ${YELLOW}${BOLD}警告: 此操作将清除所有自定义 provider、模型配置、fallback 设置${NC}"
    echo -e "  ${YELLOW}当前配置会自动备份${NC}"
    echo ""

    if ! prompt_yn "确定要还原为出厂默认配置?"; then
        echo "  已取消"
        return 0
    fi
    echo ""

    # 备份
    TIMESTAMP=$(date +%Y%m%d-%H%M%S)
    BACKUP_NAME="openclaw.json.factory-reset-${TIMESTAMP}"
    echo -n "  备份当前配置... "
    BACKUP_RESULT=$(oc_exec "cp ~/.openclaw/openclaw.json ~/.openclaw/${BACKUP_NAME} && echo OK")
    if echo "$BACKUP_RESULT" | grep -q "OK"; then
        echo -e "${GREEN}OK${NC}"
        echo -e "  ${DIM}备份: ~/.openclaw/${BACKUP_NAME}${NC}"
    else
        echo -e "${RED}备份失败，中止操作${NC}"
        return 1
    fi

    # 还原: 读取当前配置，只保留 agents/channels/bindings/tools，删除 models 相关
    echo -n "  清除 models 配置... "
    _RESET_SCRIPT=$(mktemp); _TMPFILES+=("$_RESET_SCRIPT")
    cat > "$_RESET_SCRIPT" << 'PYEOF'
import json, os

config_path = os.path.expanduser("~/.openclaw/openclaw.json")
with open(config_path) as f:
    config = json.load(f)

# 删除自定义 models 配置
if "models" in config:
    del config["models"]

with open(config_path, "w") as f:
    json.dump(config, f, indent=2, ensure_ascii=False)

print("OK")
PYEOF

    RESET_RESULT=$(python3 "$_RESET_SCRIPT" 2>&1)
    rm -f "$_RESET_SCRIPT"

    if echo "$RESET_RESULT" | grep -q "OK"; then
        echo -e "${GREEN}OK${NC}"
    else
        echo -e "${RED}失败: ${RESET_RESULT}${NC}"
        return 1
    fi

    # 清除 fallback 和 default
    echo -n "  清除 fallback... "
    oc_exec "openclaw models fallbacks clear" >/dev/null 2>&1
    echo -e "${GREEN}OK${NC}"
    echo ""

    echo -e "${GREEN}${BOLD}已还原为默认配置${NC}"
    echo ""
    echo -e "${BOLD}备份信息:${NC}"
    echo -e "  文件: ${CYAN}~/.openclaw/${BACKUP_NAME}${NC}"
    echo ""
    echo -e "${BOLD}恢复方法:${NC}"
    echo -e "  ${CYAN}cp ~/.openclaw/${BACKUP_NAME} ~/.openclaw/openclaw.json${NC}"
    echo -e "  ${CYAN}openclaw gateway stop && sleep 2 && openclaw gateway install --force${NC}"
    echo ""

    # 列出所有备份
    echo -e "${BOLD}所有备份文件:${NC}"
    oc_exec "ls -lt ~/.openclaw/openclaw.json.bak* ~/.openclaw/openclaw.json.factory-* ~/.openclaw/openclaw.json.pre-* 2>/dev/null | head -10" | while IFS= read -r line; do
        echo "  $line"
    done
    echo ""

    if prompt_yn "是否重启 Gateway?"; then
        restart_gateway
    fi
    echo ""
}

# --- 独立功能: 备份配置文件 ---
run_backup() {
    print_header "备份 OpenClaw 配置"

    local oc_dir="$HOME/.openclaw"
    local backup_dir="$oc_dir/backups"
    local timestamp
    timestamp=$(date +%Y%m%d-%H%M%S)
    local backup_name="backup-${timestamp}"
    local backup_path="${backup_dir}/${backup_name}"

    mkdir -p "$backup_path"

    local backed_up=0

    # 1. openclaw.json (核心配置)
    if [ -f "$oc_dir/openclaw.json" ]; then
        cp "$oc_dir/openclaw.json" "$backup_path/openclaw.json"
        backed_up=$((backed_up + 1))
        echo -e "  ${GREEN}✓${NC} openclaw.json"
    else
        echo -e "  ${DIM}-${NC} openclaw.json (不存在)"
    fi

    # 2. auth-profiles.json (认证信息)
    local auth_file="$oc_dir/agents/main/agent/auth-profiles.json"
    if [ -f "$auth_file" ]; then
        cp "$auth_file" "$backup_path/auth-profiles.json"
        backed_up=$((backed_up + 1))
        echo -e "  ${GREEN}✓${NC} auth-profiles.json"
    else
        echo -e "  ${DIM}-${NC} auth-profiles.json (不存在)"
    fi

    # 3. team-hierarchy.json (团队层级)
    if [ -f "$oc_dir/team-hierarchy.json" ]; then
        cp "$oc_dir/team-hierarchy.json" "$backup_path/team-hierarchy.json"
        backed_up=$((backed_up + 1))
        echo -e "  ${GREEN}✓${NC} team-hierarchy.json"
    else
        echo -e "  ${DIM}-${NC} team-hierarchy.json (不存在)"
    fi

    # 4. shell profile (环境变量 / API Key)
    local _prof
    _prof=$(detect_shell_profile)
    if [ -n "$_prof" ] && [ -f "$_prof" ]; then
        cp "$_prof" "$backup_path/$(basename "$_prof")"
        backed_up=$((backed_up + 1))
        echo -e "  ${GREEN}✓${NC} $(basename "$_prof")"
    fi

    # 5. gateway plist (LaunchAgent 配置)
    local plist_file="$HOME/Library/LaunchAgents/ai.openclaw.gateway.plist"
    if [ -f "$plist_file" ]; then
        cp "$plist_file" "$backup_path/ai.openclaw.gateway.plist"
        backed_up=$((backed_up + 1))
        echo -e "  ${GREEN}✓${NC} gateway plist"
    fi

    echo ""
    if [ "$backed_up" -gt 0 ]; then
        echo -e "  ${GREEN}${BOLD}备份完成: ${backed_up} 个文件${NC}"
        echo -e "  ${DIM}路径: ${backup_path}/${NC}"

        # 清理旧备份 (保留最近 10 个)
        local old_backups
        old_backups=$(ls -dt "$backup_dir"/backup-* 2>/dev/null | tail -n +11)
        if [ -n "$old_backups" ]; then
            local old_count
            old_count=$(echo "$old_backups" | wc -l | tr -d ' ')
            echo "$old_backups" | while read -r old; do rm -rf "$old"; done
            echo -e "  ${DIM}已清理 ${old_count} 个旧备份 (保留最近 10 个)${NC}"
        fi

        # JSON 输出
        if [ "$JSON_OUTPUT" = true ]; then
            echo ""
            python3 -c "
import json, os
backup_path = '$backup_path'
files = os.listdir(backup_path)
print(json.dumps({
    'backup_path': backup_path,
    'timestamp': '$timestamp',
    'files': files,
    'file_count': len(files)
}, indent=2, ensure_ascii=False))
"
        fi
    else
        echo -e "  ${YELLOW}未找到可备份的文件${NC}"
    fi
}

# --- 独立功能: 管理 API Key ---
run_manage_keys() {
    print_header "管理 API Key (环境变量)"

    setup_openclaw_connection || return 1

    local profile
    profile=$(detect_shell_profile)
    echo -e "  Shell Profile: ${CYAN}${profile}${NC}"
    echo ""

    # 读取现有 key
    local keys_raw
    keys_raw=$(grep '_API_KEY=' "${profile}" 2>/dev/null)

    if [ -z "$keys_raw" ]; then
        echo -e "  ${YELLOW}未找到任何 API Key 环境变量${NC}"
        echo ""
        echo -e "  使用${BOLD}一条龙向导${NC}或手动添加: export PROVIDER_API_KEY=\"sk-xxx\""
        return 0
    fi

    # 列出已有 key
    echo -e "${BOLD}已配置的 API Key:${NC}"
    echo ""
    local idx=0
    local key_names=()
    while IFS= read -r line; do
        [ -n "$line" ] || continue
        line=$(echo "$line" | sed 's/^export //')
        local var_name="${line%%=*}"
        local var_value="${line#*=}"
        var_value=$(echo "$var_value" | tr -d '"' | tr -d "'")
        idx=$((idx + 1))
        local masked="${var_value:0:8}...${var_value: -4}"
        printf "  ${CYAN}%2d)${NC} ${BOLD}%-30s${NC} %s\n" "$idx" "$var_name" "$masked"
        key_names+=("$var_name")
    done <<< "$keys_raw"
    echo ""

    echo -e "  ${CYAN}a)${NC} 添加新 Key"
    echo -e "  ${CYAN}q)${NC} 返回"
    echo ""
    local action
    action=$(prompt_choice "操作 (序号=替换, a=添加, q=返回)" "q")

    if [ "$action" = "q" ]; then
        return 0
    elif [ "$action" = "a" ]; then
        # 添加新 key
        printf "环境变量名 (如 SILICONFLOW_API_KEY): "
        read -r new_var_name
        if [ -z "$new_var_name" ]; then
            echo -e "${RED}不能为空${NC}"; return 1
        fi
        printf "API Key 值: "
        read -r new_var_value
        if [ -z "$new_var_value" ]; then
            echo -e "${RED}不能为空${NC}"; return 1
        fi

        _write_env_to_profile "$profile" "$new_var_name" "$new_var_value"
        echo ""
        if prompt_yn "是否注入 plist 并重启 Gateway?"; then
            restart_gateway
        fi
    else
        # 替换已有 key
        local sel=$((action - 1))
        if [ "$sel" -lt 0 ] || [ "$sel" -ge "${#key_names[@]}" ]; then
            echo -e "${RED}无效选择${NC}"; return 1
        fi
        local target_var="${key_names[$sel]}"
        echo -e "  替换: ${BOLD}${target_var}${NC}"
        printf "新 API Key 值: "
        read -r new_value
        if [ -z "$new_value" ]; then
            echo -e "${RED}不能为空${NC}"; return 1
        fi

        _write_env_to_profile "$profile" "$target_var" "$new_value"
        echo ""
        if prompt_yn "是否注入 plist 并重启 Gateway?"; then
            restart_gateway
        fi
    fi
    echo ""
}

# --- 写入单个环境变量到 shell profile ---
_write_env_to_profile() {
    local profile="$1" var_name="$2" var_value="$3"
    local export_line="export ${var_name}=\"${var_value}\""

    sed -i '' "/^export ${var_name}=/d" "${profile}" 2>/dev/null
    echo "${export_line}" >> "${profile}"
    echo -e "  ${GREEN}已写入${NC} ${profile}: export ${var_name}=\"${var_value:0:8}...${var_value: -4}\""
}

# --- 独立功能: 测试 API 连通 & 模型可达性 (仅收集输入，然后 fall through) ---
_collect_test_api_input() {
    print_header "测试 API 连通性 & 模型可达性"

    echo -e "${BOLD}选择 API 服务商:${NC}"
    echo ""
    echo -e "  ${DIM}--- 国内平台 (直连无障碍) ---${NC}"
    for i in "${!PROVIDER_NAMES[@]}"; do
        idx=$((i + 1))
        if [ "$idx" -eq 7 ]; then
            echo ""
            echo -e "  ${DIM}--- 全球平台 ---${NC}"
        fi
        echo -e "  ${CYAN}${idx})${NC} ${BOLD}${PROVIDER_NAMES[$i]}${NC}"
        if [ -n "${PROVIDER_FREE_INFO[$i]:-}" ]; then
            echo -e "     ${GREEN}${PROVIDER_FREE_INFO[$i]}${NC}"
        fi
    done
    echo ""
    PROVIDER_IDX=$(prompt_choice "请选择" "1")
    PROVIDER_IDX=$((PROVIDER_IDX - 1))

    if [ "$PROVIDER_IDX" -lt 0 ] || [ "$PROVIDER_IDX" -ge "${#PROVIDER_NAMES[@]}" ]; then
        echo -e "${RED}无效选择${NC}"; exit 1
    fi

    RAW_URL="${PROVIDER_URLS[$PROVIDER_IDX]}"
    if [ -z "$RAW_URL" ]; then
        printf "请输入 API Base URL: "
        read -r RAW_URL
    fi

    printf "请粘贴 API Key: "
    read -rs API_KEY
    echo
    if [ -z "$API_KEY" ]; then
        echo -e "${RED}API Key 不能为空${NC}"; exit 1
    fi
    echo ""

    DO_TEST=true
    VERBOSE=false
    # fall through to inline connectivity code below
}

# --- 参数解析 ---
DO_TEST=false
VERBOSE=false
DO_SETUP=false
DO_WIZARD=false
DO_DIAGNOSE=false
DO_MENU=false
DO_SET_DEFAULT=false
DO_ROLLBACK=false
DO_MANAGE_KEYS=false
DO_VIEW_CONFIG=false
DO_FACTORY_RESET=false
DO_BACKUP=false
DO_TEST_API=false
DO_SELFTEST=false
DO_STATUS=false
RAW_URL=""
API_KEY=""

_show_help() {
    echo -e "${BOLD}API Model Tester & OpenClaw 配置工具 v${SCRIPT_VERSION}${NC}"
    echo ""
    echo "用法:"
    echo "  $0                                    主菜单 (推荐)"
    echo "  $0 --wizard                           一条龙配置向导"
    echo "  $0 --test-api                         测试 API 可达性"
    echo "  $0 --diagnose                         诊断/清理失效配置"
    echo "  $0 --default                          设置默认模型 & Fallback"
    echo "  $0 --rollback                         回退配置"
    echo "  $0 --manage-keys                      管理 API Key"
    echo "  $0 --status                           查看当前配置 (等同菜单7)"
    echo "  $0 --selftest                         检测所有预设服务商可达性"
    echo "  $0 --backup                            备份配置文件"
    echo "  $0 --factory-reset                    还原默认配置"
    echo ""
    echo "  $0 <base_url> <api_key>               快速探测模型列表"
    echo "  $0 <base_url> <api_key> --test        探测 + 逐个测试可用性"
    echo "  $0 <base_url> <api_key> --verbose     详细模式"
    echo "  $0 <base_url> <api_key> --setup       探测 + 配置到 OpenClaw"
    echo ""
    echo "通用选项:"
    echo "  --json                                JSON 输出 (供 AI agent 读取)"
    echo "  --yes                                 跳过所有确认提示"
    echo "  --help, -h                            显示帮助"
    echo ""
}

# while/shift 解析
while [ $# -gt 0 ]; do
    case "$1" in
        --json)           JSON_OUTPUT=true ;;
        --yes)            AUTO_YES=true ;;
        --selftest)       DO_SELFTEST=true ;;
        --status)         DO_STATUS=true ;;
        --wizard)         DO_WIZARD=true ;;
        --diagnose)       DO_DIAGNOSE=true ;;
        --default)        DO_SET_DEFAULT=true ;;
        --rollback)       DO_ROLLBACK=true ;;
        --test-api)       DO_TEST_API=true ;;
        --manage-keys)    DO_MANAGE_KEYS=true ;;
        --view-config)    DO_VIEW_CONFIG=true ;;
        --backup)         DO_BACKUP=true ;;
        --factory-reset)  DO_FACTORY_RESET=true ;;
        --test)           DO_TEST=true ;;
        --verbose)        VERBOSE=true; DO_TEST=true ;;
        --setup)          DO_SETUP=true ;;
        --help|-h)        _show_help; exit 0 ;;
        -*)               echo "未知选项: $1"; _show_help; exit 1 ;;
        *)
            # 位置参数: 第一个=URL, 第二个=API_KEY
            if [ -z "$RAW_URL" ]; then
                RAW_URL="$1"
            elif [ -z "$API_KEY" ]; then
                API_KEY="$1"
            fi
            ;;
    esac
    shift
done

# 无任何 flag 也无位置参数 = 主菜单
if ! $DO_SELFTEST && ! $DO_STATUS && ! $DO_WIZARD && ! $DO_DIAGNOSE && \
   ! $DO_SET_DEFAULT && ! $DO_ROLLBACK && ! $DO_MANAGE_KEYS && \
   ! $DO_VIEW_CONFIG && ! $DO_FACTORY_RESET && ! $DO_BACKUP && ! $DO_TEST_API && \
   ! $DO_TEST && ! $DO_SETUP && [ -z "$RAW_URL" ]; then
    DO_MENU=true
fi

# =============================================
# 主菜单
# =============================================
if [ "$DO_MENU" = true ]; then
    print_header "API Model Tester & OpenClaw 配置工具"
    echo -e "  ${CYAN}1)${NC} ${BOLD}一条龙配置向导${NC} ${GREEN}(小白推荐)${NC}"
    echo -e "     ${DIM}选平台 → 输 Key → 测连通 → 探模型 → 写配置 → 设默认${NC}"
    echo ""
    echo -e "  ${CYAN}2)${NC} ${BOLD}测试 API 连通 & 模型可达性${NC}"
    echo -e "     ${DIM}仅测试，不修改任何配置${NC}"
    echo ""
    echo -e "  ${CYAN}3)${NC} ${BOLD}诊断/清理失效配置${NC}"
    echo -e "     ${DIM}扫描过期 Token、401/403 错误、僵尸 Profile${NC}"
    echo ""
    echo -e "  ${CYAN}4)${NC} ${BOLD}设置默认模型 & Fallback${NC}"
    echo -e "     ${DIM}查看所有已加载模型，更改默认和降级顺序${NC}"
    echo ""
    echo -e "  ${CYAN}5)${NC} ${BOLD}回退配置${NC}"
    echo -e "     ${DIM}从备份恢复 openclaw.json${NC}"
    echo ""
    echo -e "  ${CYAN}6)${NC} ${BOLD}管理 API Key${NC}"
    echo -e "     ${DIM}查看/替换/添加 provider 的 API Key (环境变量)${NC}"
    echo ""
    echo -e "  ${CYAN}7)${NC} ${BOLD}查看当前配置${NC}"
    echo -e "     ${DIM}Provider 概览、模型数、认证方式、默认模型、Fallback${NC}"
    echo ""
    echo -e "  ${CYAN}8)${NC} ${BOLD}还原默认配置${NC}"
    echo -e "     ${DIM}清除所有自定义 provider，恢复出厂状态 (自动备份)${NC}"
    echo ""
    echo -e "  ${CYAN}9)${NC} ${BOLD}备份配置文件${NC}"
    echo -e "     ${DIM}备份 openclaw.json + auth-profiles + shell profile${NC}"
    echo ""
    MENU_CHOICE=$(prompt_choice "请选择" "1")
    case "$MENU_CHOICE" in
        1) DO_WIZARD=true ;;
        2) DO_TEST_API=true ;;
        3) DO_DIAGNOSE=true ;;
        4) DO_SET_DEFAULT=true ;;
        5) DO_ROLLBACK=true ;;
        6) DO_MANAGE_KEYS=true ;;
        7) DO_VIEW_CONFIG=true ;;
        8) DO_FACTORY_RESET=true ;;
        9) DO_BACKUP=true ;;
        *) echo -e "${RED}无效选择${NC}"; exit 1 ;;
    esac
fi

# --- 分发独立功能 ---
if [ "$DO_SELFTEST" = true ]; then
    run_selftest
    exit 0
fi

if [ "$DO_STATUS" = true ]; then
    if [ "$JSON_OUTPUT" = true ]; then
        run_status_json
    else
        DO_VIEW_CONFIG=true
    fi
    [ "$DO_VIEW_CONFIG" != true ] && exit 0
fi

if [ "$DO_SET_DEFAULT" = true ]; then
    run_set_default
    exit 0
fi

if [ "$DO_ROLLBACK" = true ]; then
    run_rollback
    exit 0
fi

if [ "$DO_MANAGE_KEYS" = true ]; then
    run_manage_keys
    exit 0
fi

if [ "$DO_VIEW_CONFIG" = true ]; then
    run_view_config
    exit 0
fi

if [ "$DO_FACTORY_RESET" = true ]; then
    run_factory_reset
    exit 0
fi

if [ "$DO_BACKUP" = true ]; then
    run_backup
    exit 0
fi

if [ "$DO_TEST_API" = true ]; then
    _collect_test_api_input
    # fall through to connectivity section below
fi

# =============================================
# 诊断模式
# =============================================
run_diagnose() {
    if [ "$JSON_OUTPUT" != true ]; then
        print_header "OpenClaw 模型 & 认证诊断"
        echo -n "  检测 OpenClaw... "
    fi

    # 检测 openclaw
    local oc_ver
    oc_ver=$(openclaw --version 2>/dev/null | head -1)
    if [ -z "$oc_ver" ]; then
        if [ "$JSON_OUTPUT" = true ]; then
            echo '{"error": "openclaw not found"}'
        else
            echo -e "${RED}未找到 openclaw${NC}"
        fi
        return 1
    fi
    if [ "$JSON_OUTPUT" != true ]; then
        echo -e "${GREEN}${oc_ver}${NC}"
        echo ""
    fi

    # 获取完整状态
    local status_json
    status_json=$(openclaw models status --json 2>/dev/null)

    # 获取 auth-profiles.json
    local profiles_json
    profiles_json=$(cat ~/.openclaw/agents/main/agent/auth-profiles.json 2>/dev/null)

    # Python 诊断分析
    _DIAG_SCRIPT=$(mktemp); _TMPFILES+=("$_DIAG_SCRIPT")
    cat > "$_DIAG_SCRIPT" << 'PYEOF'
import json, sys, os, time

try:
    status = json.loads(os.environ.get("STATUS_JSON") or "{}")
except:
    status = {}
try:
    profiles_data = json.loads(os.environ.get("PROFILES_JSON") or "{}")
except:
    profiles_data = {}

auth = status.get("auth", {})
default_model = status.get("defaultModel", "")
fallbacks = status.get("fallbacks", [])
aliases = status.get("aliases", {})

# Collect issues
issues = []
warnings = []
info = []
cleanup_candidates = []

now_ms = time.time() * 1000

# 1. Check model config
info.append(f"默认模型: {default_model or '未设置'}")
if fallbacks:
    info.append(f"Fallback: {', '.join(fallbacks)}")
else:
    warnings.append("未配置 fallback — 默认模型不可用时无法自动切换")

# 2. Check auth profiles
oauth_profiles = auth.get("oauth", {}).get("profiles", [])
usage_stats = profiles_data.get("usageStats", {})
stored_profiles = profiles_data.get("profiles", {})
config_profiles = auth.get("storePath", "")

for p in oauth_profiles:
    pid = p.get("profileId", "?")
    ptype = p.get("type", "?")
    pstatus = p.get("status", "?")
    remaining = p.get("remainingMs")
    provider = p.get("provider", "?")

    # Check expiry
    if remaining is not None and remaining < 0:
        hours_ago = abs(remaining) / 3600000
        issues.append(f"EXPIRED: {pid} — OAuth 已过期 {hours_ago:.0f}小时前")
        cleanup_candidates.append(pid)
    elif remaining is not None and remaining < 3600000:  # < 1h
        warnings.append(f"EXPIRING: {pid} — 将在 {remaining/60000:.0f}分钟后过期")

# 3. Check usage stats for error patterns
for pid, stats in usage_stats.items():
    err_count = stats.get("errorCount", 0)
    failure_counts = stats.get("failureCounts", {})
    cooldown = stats.get("cooldownUntil")
    last_fail = stats.get("lastFailureAt")

    if err_count > 0:
        auth_errs = failure_counts.get("auth", 0)
        rate_errs = failure_counts.get("rate", 0)

        if auth_errs > 0:
            issues.append(f"AUTH_FAIL: {pid} — {auth_errs}次认证失败 (401/403)")
            if auth_errs >= 3:
                cleanup_candidates.append(pid)
        if rate_errs > 0:
            warnings.append(f"RATE_LIMIT: {pid} — {rate_errs}次限流")
        if err_count > 0 and auth_errs == 0 and rate_errs == 0:
            warnings.append(f"ERRORS: {pid} — {err_count}次错误")

        if cooldown:
            if cooldown > now_ms:
                remaining_h = (cooldown - now_ms) / 3600000
                issues.append(f"COOLDOWN: {pid} — 冷却中，{remaining_h:.1f}小时后恢复")
            # expired cooldown with errors is still a warning
            elif auth_errs >= 3:
                warnings.append(f"STALE_COOLDOWN: {pid} — 冷却已过但有{auth_errs}次auth失败，建议清理")

# 4. Check for ghost profiles (in config but not in stored profiles)
config_auth = auth.get("profiles", status.get("auth", {}).get("profiles", {}))
# Check from config profiles reference
for p in oauth_profiles:
    pid = p.get("profileId", "")
    if pid and pid not in stored_profiles:
        warnings.append(f"GHOST: {pid} — 在 config 中引用但 auth-profiles.json 中不存在")
        cleanup_candidates.append(pid)

# 5. Check for orphan profiles (in stored but not referenced)
referenced_pids = set(p.get("profileId", "") for p in oauth_profiles)
for pid in stored_profiles:
    if pid not in referenced_pids:
        warnings.append(f"ORPHAN: {pid} — 存在于 auth-profiles.json 但未被 config 引用")

# Deduplicate cleanup candidates
cleanup_candidates = list(dict.fromkeys(cleanup_candidates))

# Build profile details
profile_details = []
for p in oauth_profiles:
    pid = p.get("profileId", "?")
    ptype = p.get("type", "?")
    pstatus = p.get("status", "?")
    provider = p.get("provider", "?")
    remaining = p.get("remainingMs")
    errs = usage_stats.get(pid, {}).get("errorCount", 0)
    exp_str = ""
    if remaining is not None:
        if remaining < 0:
            exp_str = f"expired:{abs(remaining)/3600000:.0f}h_ago"
        else:
            exp_str = f"expires:{remaining/3600000:.1f}h"
    profile_details.append({
        "id": pid, "provider": provider, "type": ptype,
        "status": pstatus, "errors": errs, "expiry": exp_str
    })

# JSON output mode
if os.environ.get("JSON_MODE") == "true":
    result = {
        "info": info,
        "issues": issues,
        "warnings": warnings,
        "cleanup_candidates": cleanup_candidates,
        "profiles": profile_details,
        "healthy": len(issues) == 0 and len(warnings) == 0
    }
    print(json.dumps(result, indent=2, ensure_ascii=False))
else:
    # TUI output
    print("=== DIAG_RESULT ===")
    print(f"INFO_COUNT:{len(info)}")
    for i in info:
        print(f"INFO:{i}")
    print(f"ISSUE_COUNT:{len(issues)}")
    for i in issues:
        print(f"ISSUE:{i}")
    print(f"WARNING_COUNT:{len(warnings)}")
    for w in warnings:
        print(f"WARNING:{w}")
    print(f"CLEANUP_COUNT:{len(cleanup_candidates)}")
    for c in cleanup_candidates:
        print(f"CLEANUP:{c}")
    print(f"PROFILE_COUNT:{len(profile_details)}")
    for pd in profile_details:
        print(f"PROFILE:{pd['id']}|{pd['provider']}|{pd['type']}|{pd['status']}|errs={pd['errors']}|{pd['expiry']}")
PYEOF

    DIAG_RESULT=$(STATUS_JSON="$status_json" PROFILES_JSON="$profiles_json" JSON_MODE="$JSON_OUTPUT" python3 "$_DIAG_SCRIPT" 2>&1)
    rm -f "$_DIAG_SCRIPT"

    # JSON mode: direct output and return
    if [ "$JSON_OUTPUT" = true ]; then
        echo "$DIAG_RESULT"
        return 0
    fi

    # Parse and display results
    echo -e "${BOLD}认证 Profile 一览:${NC}"
    echo "────────────────────────────────────────────────────────────"
    echo "$DIAG_RESULT" | grep "^PROFILE:" | while IFS='|' read -r raw provider ptype pstatus errs expiry; do
        pid="${raw#PROFILE:}"
        # Color code status
        local status_color="${GREEN}"
        if echo "$pstatus" | grep -q "static"; then
            status_color="${CYAN}"
        fi
        if echo "$errs" | grep -qv "errs=0"; then
            status_color="${RED}"
        fi
        if echo "$expiry" | grep -q "expired"; then
            status_color="${RED}"
        fi
        printf "  ${status_color}%-38s${NC} %s %-8s %s %s\n" "$pid" "$provider" "$ptype" "$errs" "$expiry"
    done
    echo "────────────────────────────────────────────────────────────"
    echo ""

    # Info
    echo "$DIAG_RESULT" | grep "^INFO:" | while read -r line; do
        echo -e "  ${CYAN}ℹ${NC}  ${line#INFO:}"
    done
    echo ""

    # Issues (red)
    ISSUE_COUNT=$(echo "$DIAG_RESULT" | grep "^ISSUE_COUNT:" | cut -d: -f2)
    ISSUE_COUNT=${ISSUE_COUNT:-0}
    if [ "$ISSUE_COUNT" -gt 0 ]; then
        echo -e "${RED}${BOLD}问题 (${ISSUE_COUNT}):${NC}"
        echo "$DIAG_RESULT" | grep "^ISSUE:" | while read -r line; do
            echo -e "  ${RED}✗${NC}  ${line#ISSUE:}"
        done
        echo ""
    fi

    # Warnings (yellow)
    WARNING_COUNT=$(echo "$DIAG_RESULT" | grep "^WARNING_COUNT:" | cut -d: -f2)
    WARNING_COUNT=${WARNING_COUNT:-0}
    if [ "$WARNING_COUNT" -gt 0 ]; then
        echo -e "${YELLOW}${BOLD}警告 (${WARNING_COUNT}):${NC}"
        echo "$DIAG_RESULT" | grep "^WARNING:" | while read -r line; do
            echo -e "  ${YELLOW}!${NC}  ${line#WARNING:}"
        done
        echo ""
    fi

    # No issues
    if [ "$ISSUE_COUNT" -eq 0 ] && [ "$WARNING_COUNT" -eq 0 ]; then
        echo -e "${GREEN}${BOLD}未发现问题 — 认证配置健康${NC}"
        echo ""
        return 0
    fi

    # Cleanup offer
    CLEANUP_COUNT=$(echo "$DIAG_RESULT" | grep "^CLEANUP_COUNT:" | cut -d: -f2)
    CLEANUP_COUNT=${CLEANUP_COUNT:-0}
    if [ "$CLEANUP_COUNT" -gt 0 ]; then
        echo -e "${BOLD}建议清理的 Profile (${CLEANUP_COUNT}):${NC}"
        echo "$DIAG_RESULT" | grep "^CLEANUP:" | while read -r line; do
            echo -e "  ${DIM}${line#CLEANUP:}${NC}"
        done
        echo ""

        if prompt_yn "是否清理这些失效/问题 Profile?"; then
            echo ""
            CLEANUP_LIST=$(echo "$DIAG_RESULT" | grep "^CLEANUP:" | sed 's/^CLEANUP://')

            _CLEANUP_SCRIPT=$(mktemp); _TMPFILES+=("$_CLEANUP_SCRIPT")
            cat > "$_CLEANUP_SCRIPT" << 'PYEOF'
import json, sys, os

profiles_path = os.path.expanduser("~/.openclaw/agents/main/agent/auth-profiles.json")
config_path = os.path.expanduser("~/.openclaw/openclaw.json")
cleanup_ids = [x.strip() for x in os.environ.get("CLEANUP_IDS", "").split("\n") if x.strip()]

if not cleanup_ids:
    print("SKIP:nothing to clean")
    sys.exit(0)

# Backup
import shutil
shutil.copy(profiles_path, profiles_path + ".bak-diagnose")

# Clean auth-profiles.json
with open(profiles_path) as f:
    pdata = json.loads(f.read())

removed = []
for cid in cleanup_ids:
    if cid in pdata.get("profiles", {}):
        del pdata["profiles"][cid]
        removed.append(cid)
    # Clean usage stats
    if cid in pdata.get("usageStats", {}):
        del pdata["usageStats"][cid]
    # Clean from order lists
    for provider, order_list in pdata.get("order", {}).items():
        if cid in order_list:
            order_list.remove(cid)
    # Clean from lastGood
    for provider, last in list(pdata.get("lastGood", {}).items()):
        if last == cid:
            del pdata["lastGood"][provider]

with open(profiles_path, "w") as f:
    json.dump(pdata, f, indent=2, ensure_ascii=False)

# Also clean config auth.profiles references
try:
    with open(config_path) as f:
        config = json.loads(f.read())
    config_changed = False
    for cid in cleanup_ids:
        if cid in config.get("auth", {}).get("profiles", {}):
            del config["auth"]["profiles"][cid]
            config_changed = True
    if config_changed:
        shutil.copy(config_path, config_path + ".bak-diagnose")
        with open(config_path, "w") as f:
            json.dump(config, f, indent=2, ensure_ascii=False)
except:
    pass

print(f"OK:{len(removed)}")
for r in removed:
    print(f"REMOVED:{r}")
PYEOF

            CLEANUP_RESULT=$(CLEANUP_IDS="${CLEANUP_LIST}" python3 "$_CLEANUP_SCRIPT" 2>&1)
            rm -f "$_CLEANUP_SCRIPT"

            if [[ "$CLEANUP_RESULT" == OK:* ]]; then
                REMOVED_COUNT=$(echo "$CLEANUP_RESULT" | head -1 | cut -d: -f2)
                echo -e "  ${GREEN}已清理 ${REMOVED_COUNT} 个 Profile${NC}"
                echo "$CLEANUP_RESULT" | grep "^REMOVED:" | while read -r line; do
                    echo -e "  ${DIM}  移除: ${line#REMOVED:}${NC}"
                done
                echo ""
                echo -e "  ${DIM}备份: auth-profiles.json.bak-diagnose${NC}"
            else
                echo -e "  ${RED}清理失败: ${CLEANUP_RESULT}${NC}"
            fi
            echo ""
        fi
    fi

    # Suggest next steps
    echo -e "${BOLD}后续建议:${NC}"
    if [ "$ISSUE_COUNT" -gt 0 ]; then
        echo -e "  ${CYAN}# 重新配置失效的认证${NC}"
        echo "  openclaw models auth add"
        echo ""
        echo -e "  ${CYAN}# 或粘贴新 token${NC}"
        echo "  openclaw models auth paste-token --provider anthropic"
        echo ""
    fi
    echo -e "  ${CYAN}# 重启 gateway 使变更生效${NC}"
    echo "  openclaw gateway stop && sleep 2 && openclaw gateway install --force"
    echo ""

    if prompt_yn "是否重启 Gateway?"; then
        echo ""
        restart_gateway
    fi
    echo ""
}

# --- 运行诊断 (独立模式) ---
if [ "$DO_DIAGNOSE" = true ]; then
    run_diagnose
    exit 0
fi

# =============================================
# 向导模式
# =============================================
if [ "$DO_WIZARD" = true ]; then

print_header "API Model Tester & OpenClaw 模型配置向导"

# --- Step 1: 选择服务商 ---
print_step "1/6" "选择 API 服务商"
echo ""
echo -e "  ${DIM}--- 国内平台 (直连无障碍) ---${NC}"
for i in "${!PROVIDER_NAMES[@]}"; do
    idx=$((i + 1))
    # 在全球平台第一个前加分隔
    if [ "$idx" -eq 7 ]; then
        echo ""
        echo -e "  ${DIM}--- 全球平台 ---${NC}"
    fi
    echo -e "  ${CYAN}${idx})${NC} ${BOLD}${PROVIDER_NAMES[$i]}${NC}"
    echo -e "     ${DIM}${PROVIDER_DESCS[$i]}${NC}"
    if [ -n "${PROVIDER_FREE_INFO[$i]:-}" ]; then
        echo -e "     ${GREEN}白嫖: ${PROVIDER_FREE_INFO[$i]}${NC}"
    fi
    if [ -n "${PROVIDER_REFERRALS[$i]:-}" ]; then
        echo -e "     ${DIM}注册: ${PROVIDER_REFERRALS[$i]}${NC}"
    fi
done
echo ""
PROVIDER_IDX=$(prompt_choice "请选择" "1")
PROVIDER_IDX=$((PROVIDER_IDX - 1))

if [ "$PROVIDER_IDX" -lt 0 ] || [ "$PROVIDER_IDX" -ge "${#PROVIDER_NAMES[@]}" ]; then
    echo -e "${RED}无效选择${NC}"
    exit 1
fi

SELECTED_PROVIDER="${PROVIDER_NAMES[$PROVIDER_IDX]}"
RAW_URL="${PROVIDER_URLS[$PROVIDER_IDX]}"
SELECTED_REFERRAL="${PROVIDER_REFERRALS[$PROVIDER_IDX]:-}"
SELECTED_FREE="${PROVIDER_FREE_INFO[$PROVIDER_IDX]:-}"

echo -e "  已选择: ${GREEN}${SELECTED_PROVIDER}${NC}"
if [ -n "$SELECTED_FREE" ]; then
    echo -e "  ${GREEN}白嫖福利: ${SELECTED_FREE}${NC}"
fi
if [ -n "$SELECTED_REFERRAL" ]; then
    echo ""
    echo -e "  ${BOLD}还没有 API Key? 点击注册:${NC}"
    echo -e "  ${CYAN}${SELECTED_REFERRAL}${NC}"
fi
echo ""

if [ -z "$RAW_URL" ]; then
    printf "请输入 API Base URL: "
    read -r RAW_URL
    if [ -z "$RAW_URL" ]; then
        echo -e "${RED}URL 不能为空${NC}"
        exit 1
    fi
fi

echo ""

# --- Step 2: 输入 API Key ---
print_step "2/6" "输入 API Key"
echo ""
printf "请粘贴 API Key: "
read -rs API_KEY
echo
if [ -z "$API_KEY" ]; then
    echo -e "${RED}API Key 不能为空${NC}"
    exit 1
fi
echo -e "  Key: ${GREEN}${API_KEY:0:8}...${API_KEY: -4}${NC}"
echo ""

fi  # end wizard input collection

# =============================================
# 连通性检测 + 模型发现 (向导和命令行共用)
# =============================================
BASE_URL=$(normalize_base_url "$RAW_URL")
MODELS_URL="${BASE_URL}/models"
CHAT_URL="${BASE_URL}/chat/completions"

if [ "$DO_WIZARD" = true ]; then
    print_step "3/6" "连通性检测 & 模型发现"
else
    print_header "API Model Tester"
    echo -e " Base URL:   ${CYAN}${BASE_URL}${NC}"
    echo -e " API Key:    ${CYAN}${API_KEY:0:8}...${API_KEY: -4}${NC}"
fi
echo ""

# --- 3a: 网络连通性 ---
echo -n "  检测网络连通性... "
NET_CHECK=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "${BASE_URL}" 2>&1)
if [ $? -ne 0 ] || [ -z "$NET_CHECK" ]; then
    echo -e "${RED}失败 — 无法连接到 ${BASE_URL}${NC}"
    echo "  请检查网络或 URL 是否正确"
    exit 1
fi
echo -e "${GREEN}OK${NC}"

# --- 3b: API Key 验证 ---
echo -n "  验证 API Key... "
if [ "$VERBOSE" = true ]; then
    print_curl_cmd "GET" "${MODELS_URL}"
fi

KEY_RESPONSE=$(curl -s -w "\n%{http_code}|%{time_total}s" "${MODELS_URL}" \
    -H "Authorization: Bearer ${API_KEY}" \
    -H "Content-Type: application/json" 2>&1)

META_LINE=$(echo "$KEY_RESPONSE" | tail -1)
HTTP_CODE=$(echo "$META_LINE" | cut -d'|' -f1)
ELAPSED=$(echo "$META_LINE" | cut -d'|' -f2)
BODY=$(echo "$KEY_RESPONSE" | sed '$d')

if [ "$VERBOSE" = true ]; then
    print_response "$HTTP_CODE" "$BODY" "$ELAPSED"
fi

if [ "$HTTP_CODE" = "401" ] || [ "$HTTP_CODE" = "403" ]; then
    echo -e "${RED}失败 — API Key 无效或已过期 (HTTP ${HTTP_CODE})${NC}"
    echo "$BODY" | python3 -m json.tool 2>/dev/null || echo "$BODY"
    exit 1
elif [ "$HTTP_CODE" != "200" ]; then
    echo -e "${YELLOW}警告 — 模型列表返回 HTTP ${HTTP_CODE}，尝试继续...${NC}"
else
    echo -e "${GREEN}OK${NC} ${DIM}(${ELAPSED})${NC}"
fi

# --- 3c: 解析模型列表 ---
echo -n "  获取模型列表... "

_PY_SCRIPT=$(mktemp); _TMPFILES+=("$_PY_SCRIPT")
cat > "$_PY_SCRIPT" << 'PYEOF'
import json, sys, os

try:
    data = json.loads(os.environ["API_BODY"])
except:
    print("PARSE_ERROR")
    sys.exit(1)

models = data if isinstance(data, list) else data.get("data", [])
if not models:
    print("NO_MODELS")
    sys.exit(0)

categories = {}
chat_models = []
non_chat = []

for m in models:
    mid = m["id"] if isinstance(m, dict) else str(m)
    name = mid.lower()

    # 分类 (embedding/rerank 优先判断)
    if "bge" in name or "embed" in name or "rerank" in name: cat = "Embedding/Rerank"
    elif "deepseek" in name: cat = "DeepSeek"
    elif "qwen" in name: cat = "Qwen"
    elif "glm" in name or "chatglm" in name: cat = "GLM"
    elif "kimi" in name or "moonshot" in name: cat = "Kimi/Moonshot"
    elif "minimax" in name or "abab" in name: cat = "MiniMax"
    elif "gpt" in name: cat = "GPT"
    elif "claude" in name: cat = "Claude"
    elif "gemini" in name or "gemma" in name: cat = "Google"
    elif "llama" in name or "meta" in name: cat = "Meta/Llama"
    elif "mistral" in name or "mixtral" in name: cat = "Mistral"
    elif "yi-" in name or name.startswith("yi"): cat = "Yi"
    elif "kat" in name: cat = "KAT"
    elif "internlm" in name: cat = "InternLM"
    elif "baichuan" in name: cat = "Baichuan"
    elif "whisper" in name or "tts" in name: cat = "Audio"
    elif "dall" in name or "flux" in name or "stable" in name or "image" in name: cat = "Image"
    else: cat = "Other"

    categories.setdefault(cat, []).append(mid)

    # chat vs non-chat
    if cat in ("Embedding/Rerank", "Audio", "Image"):
        non_chat.append(mid)
    else:
        chat_models.append(mid)

total = sum(len(v) for v in categories.values())
print(f"TOTAL:{total}")
print(f"CHAT_COUNT:{len(chat_models)}")
for cat in sorted(categories.keys()):
    models_list = sorted(categories[cat])
    print(f"CAT:{cat}:{','.join(models_list)}")
for mid in chat_models:
    print(f"CHAT:{mid}")
for mid in non_chat:
    print(f"NONCHAT:{mid}")
PYEOF
MODEL_INFO=$(API_BODY="$BODY" python3 "$_PY_SCRIPT")
rm -f "$_PY_SCRIPT"

if echo "$MODEL_INFO" | grep -q "PARSE_ERROR"; then
    echo -e "${RED}解析失败${NC}"
    echo "$BODY" | head -20
    exit 1
fi

if echo "$MODEL_INFO" | grep -q "NO_MODELS"; then
    echo -e "${YELLOW}该 Key 没有可用模型${NC}"
    exit 0
fi

TOTAL=$(echo "$MODEL_INFO" | grep "^TOTAL:" | cut -d: -f2)
CHAT_COUNT=$(echo "$MODEL_INFO" | grep "^CHAT_COUNT:" | cut -d: -f2)
echo -e "${GREEN}发现 ${TOTAL} 个模型 (${CHAT_COUNT} 个 chat 模型)${NC}"
echo ""

# 显示分类表
echo -e "${BOLD}模型列表:${NC}"
echo "----------------------------------------"
echo "$MODEL_INFO" | grep "^CAT:" | while IFS=: read -r _ cat models_csv; do
    count=$(echo "$models_csv" | tr ',' '\n' | wc -l | tr -d ' ')
    echo -e "${CYAN}${cat}${NC} (${count}个):"
    echo "$models_csv" | tr ',' '\n' | while read -r m; do
        echo "  - $m"
    done
done
echo "----------------------------------------"
echo ""

# --- 可选: 逐个测试 ---
if [ "$DO_TEST" = true ]; then
    echo -e "${BOLD}逐个测试模型可用性...${NC}"
    echo ""

    ALL_MODELS=$(echo "$MODEL_INFO" | grep "^CHAT:" | cut -d: -f2-)
    OK_MODELS=""
    FAIL_MODELS=""
    OK_COUNT=0
    FAIL_COUNT=0
    IDX=0

    for model_id in $ALL_MODELS; do
        IDX=$((IDX + 1))
        printf "  [%d/%d] %-45s " "$IDX" "$CHAT_COUNT" "$model_id"

        REQ_BODY="{\"model\": \"${model_id}\", \"messages\": [{\"role\": \"user\", \"content\": \"hi\"}], \"max_tokens\": 5}"

        if [ "$VERBOSE" = true ]; then
            print_curl_cmd "POST" "${CHAT_URL}" "$REQ_BODY"
        fi

        RESULT_RAW=$(curl -s -m 30 -w "\n%{http_code}|%{time_total}s" "${CHAT_URL}" \
            -H "Authorization: Bearer ${API_KEY}" \
            -H "Content-Type: application/json" \
            -d "$REQ_BODY" 2>&1)

        RESULT_META=$(echo "$RESULT_RAW" | tail -1)
        RESULT_HTTP=$(echo "$RESULT_META" | cut -d'|' -f1)
        RESULT_TIME=$(echo "$RESULT_META" | cut -d'|' -f2)
        RESULT=$(echo "$RESULT_RAW" | sed '$d')

        if [ "$VERBOSE" = true ]; then
            print_response "$RESULT_HTTP" "$RESULT" "$RESULT_TIME"
        fi

        STATUS=$(echo "$RESULT" | python3 -c "
import sys, json
try:
    d = json.loads(sys.stdin.read())
    code = d.get('code', d.get('error', {}).get('code', ''))
    if code and str(code) != '0':
        msg = d.get('message', d.get('error', {}).get('message', str(code)))
        print(f'FAIL:{msg}')
    elif 'choices' in d:
        print('OK')
    elif 'error' in d:
        print(f'FAIL:{d[\"error\"].get(\"message\", \"unknown error\")}')
    else:
        print('OK')
except:
    print('FAIL:invalid response')
" 2>/dev/null || echo "FAIL:timeout or network error")

        if [[ "$STATUS" == "OK" ]]; then
            echo -e "${GREEN}OK${NC} ${DIM}(${RESULT_TIME})${NC}"
            OK_MODELS="${OK_MODELS}${model_id}\n"
            OK_COUNT=$((OK_COUNT + 1))
        else
            REASON="${STATUS#FAIL:}"
            if [ ${#REASON} -gt 50 ]; then
                REASON="${REASON:0:47}..."
            fi
            echo -e "${RED}FAIL${NC} - ${REASON}"
            FAIL_MODELS="${FAIL_MODELS}${model_id}\n"
            FAIL_COUNT=$((FAIL_COUNT + 1))
        fi
    done

    echo ""
    echo -e " ${GREEN}可用: ${OK_COUNT}${NC} / ${RED}不可用: ${FAIL_COUNT}${NC} / 总计: ${CHAT_COUNT}"
    if [ "$OK_COUNT" -gt 0 ]; then
        echo ""
        echo -e "${GREEN}可用模型:${NC}"
        echo -e "$OK_MODELS" | sed '/^$/d' | while read -r m; do echo "  $m"; done
    fi
    echo ""
fi

# =============================================
# OpenClaw 配置 (向导模式 Step 4-6 或 --setup)
# =============================================
if [ "$DO_WIZARD" = false ] && [ "$DO_SETUP" = false ]; then
    if [ "$DO_TEST" = false ]; then
        echo -e "${YELLOW}提示: 加 --test 逐个测试 | --setup 配置到 OpenClaw | 不带参数进入向导模式${NC}"
    fi
    exit 0
fi

if [ "$DO_WIZARD" = true ]; then
    echo ""
    if ! prompt_yn "是否将模型配置到 OpenClaw?"; then
        echo -e "${GREEN}探测完成，已退出${NC}"
        exit 0
    fi
    echo ""
fi

# --- Step 4: 连接 OpenClaw ---
if [ "$DO_WIZARD" = true ]; then
    print_step "4/6" "连接 OpenClaw"
else
    print_header "配置到 OpenClaw"
fi
echo ""

setup_openclaw_connection || exit 1

# --- 可达性检测 & 模型选择 ---
CHAT_MODELS=$(echo "$MODEL_INFO" | grep "^CHAT:" | cut -d: -f2-)

echo -e "${BOLD}检测模型可达性...${NC} ${DIM}(每个模型超时 10s)${NC}"
echo ""

# 逐个测试可达性，结果写入临时文件
_REACH_FILE=$(mktemp); _TMPFILES+=("$_REACH_FILE")
REACH_OK=0
REACH_FAIL=0
REACH_IDX=0

while IFS= read -r model_id; do
    [ -n "$model_id" ] || continue
    REACH_IDX=$((REACH_IDX + 1))
    printf "  [%d/%d] %-45s " "$REACH_IDX" "$CHAT_COUNT" "$model_id"

    RESULT=$(curl -s -m 10 -w "\n%{http_code}" "${CHAT_URL}" \
        -H "Authorization: Bearer ${API_KEY}" \
        -H "Content-Type: application/json" \
        -d "{\"model\": \"${model_id}\", \"messages\": [{\"role\": \"user\", \"content\": \"hi\"}], \"max_tokens\": 5}" 2>&1)

    R_HTTP=$(echo "$RESULT" | tail -1)
    R_BODY=$(echo "$RESULT" | sed '$d')

    # 判断可达性
    R_STATUS=$(echo "$R_BODY" | python3 -c "
import sys, json
try:
    d = json.loads(sys.stdin.read())
    code = d.get('code', d.get('error', {}).get('code', ''))
    if code and str(code) != '0':
        msg = d.get('message', d.get('error', {}).get('message', str(code)))
        print(f'FAIL:{msg}')
    elif 'choices' in d:
        print('OK')
    elif 'error' in d:
        print(f'FAIL:{d[\"error\"].get(\"message\", \"unknown error\")}')
    else:
        print('OK')
except:
    print('FAIL:unreachable')
" 2>/dev/null || echo "FAIL:timeout")

    if [[ "$R_STATUS" == "OK" ]]; then
        echo -e "${GREEN}可达${NC}"
        echo "OK:${model_id}" >> "$_REACH_FILE"
        REACH_OK=$((REACH_OK + 1))
    else
        REASON="${R_STATUS#FAIL:}"
        if [ ${#REASON} -gt 40 ]; then REASON="${REASON:0:37}..."; fi
        echo -e "${RED}不可达${NC} ${DIM}(${REASON})${NC}"
        echo "FAIL:${model_id}" >> "$_REACH_FILE"
        REACH_FAIL=$((REACH_FAIL + 1))
    fi
done <<< "$CHAT_MODELS"

echo ""
echo -e "  ${GREEN}可达: ${REACH_OK}${NC} / ${RED}不可达: ${REACH_FAIL}${NC} / 总计: ${CHAT_COUNT}"
echo ""

# 构建可达/不可达列表
REACHABLE_MODELS=$(grep "^OK:" "$_REACH_FILE" | cut -d: -f2-)
UNREACHABLE_MODELS=$(grep "^FAIL:" "$_REACH_FILE" | cut -d: -f2-)
rm -f "$_REACH_FILE"

# 模型选择
echo -e "${BOLD}选择要配置的模型:${NC}"
if [ "$REACH_FAIL" -gt 0 ]; then
    REACHABLE_COUNT=$(echo "$REACHABLE_MODELS" | sed '/^$/d' | wc -l | tr -d ' ')
    echo "  1) 仅可达的 ${REACHABLE_COUNT} 个模型 (推荐)"
    echo "  2) 全部 ${CHAT_COUNT} 个 chat 模型 (含不可达)"
    echo "  3) 手动选择"
    MODEL_CHOICE=$(prompt_choice "请选择" "1")
else
    echo "  1) 全部 ${CHAT_COUNT} 个 chat 模型 (全部可达)"
    echo "  2) 手动选择"
    MODEL_CHOICE=$(prompt_choice "请选择" "1")
fi

SELECTED_MODELS=""
if { [ "$REACH_FAIL" -gt 0 ] && [ "$MODEL_CHOICE" = "3" ]; } || \
   { [ "$REACH_FAIL" -eq 0 ] && [ "$MODEL_CHOICE" = "2" ]; }; then
    echo ""
    IDX=0
    echo "$CHAT_MODELS" | while read -r mid; do
        IDX=$((IDX + 1))
        if echo "$REACHABLE_MODELS" | grep -qx "$mid" 2>/dev/null; then
            printf "  ${GREEN}%2d) %s${NC}\n" "$IDX" "$mid"
        else
            printf "  ${RED}%2d) %s (不可达)${NC}\n" "$IDX" "$mid"
        fi
    done
    echo ""
    printf "输入编号 (逗号分隔, 如 1,3,5): "
    read -r SELECTIONS
    MODELS_ARRAY=()
    while IFS= read -r mid; do
        MODELS_ARRAY+=("$mid")
    done <<< "$CHAT_MODELS"
    for sel in $(echo "$SELECTIONS" | tr ',' ' '); do
        idx=$((sel - 1))
        if [ "$idx" -ge 0 ] && [ "$idx" -lt "${#MODELS_ARRAY[@]}" ]; then
            SELECTED_MODELS="${SELECTED_MODELS}${MODELS_ARRAY[$idx]}"$'\n'
        fi
    done
    SELECTED_MODELS=$(echo "$SELECTED_MODELS" | sed '/^$/d')
elif [ "$REACH_FAIL" -gt 0 ] && [ "$MODEL_CHOICE" = "1" ]; then
    SELECTED_MODELS="$REACHABLE_MODELS"
elif [ "$REACH_FAIL" -gt 0 ] && [ "$MODEL_CHOICE" = "2" ]; then
    SELECTED_MODELS="$CHAT_MODELS"
else
    SELECTED_MODELS="$CHAT_MODELS"
fi

SEL_COUNT=$(echo "$SELECTED_MODELS" | sed '/^$/d' | wc -l | tr -d ' ')
echo -e "  已选择 ${GREEN}${SEL_COUNT}${NC} 个模型"
echo ""

# Provider 名称
URL_HOST=$(echo "$BASE_URL" | sed -E 's|https?://||;s|/.*||' | sed -E 's/^(api[0-9]*|integrate)\.//' | sed -E 's/\.(com|net|ai|cn|top|org)$//' | sed -E 's/^api\.//' | rev | cut -d. -f1 | rev)
PROVIDER_NAME=$(prompt_choice "Provider 名称 (用于 OpenClaw 标识)" "$URL_HOST")
echo ""

# --- 写入配置 (环境变量模式) ---
echo -e "${BOLD}写入 provider 配置...${NC}"

# 生成环境变量名: provider_name 大写 + _API_KEY
ENV_VAR_NAME=$(echo "${PROVIDER_NAME}" | tr '[:lower:]-' '[:upper:]_')_API_KEY
echo -e "  ${DIM}API Key 将通过环境变量 \$${ENV_VAR_NAME} 引用${NC}"
echo ""

_SETUP_SCRIPT=$(mktemp); _TMPFILES+=("$_SETUP_SCRIPT")
cat > "$_SETUP_SCRIPT" << 'PYEOF'
import json, sys, os, shutil

config_path = os.path.expanduser("~/.openclaw/openclaw.json")

try:
    with open(config_path) as f:
        config = json.loads(f.read())
except FileNotFoundError:
    config = {}

provider_name = os.environ["PROVIDER_NAME"]
base_url = os.environ["BASE_URL"]
env_var_name = os.environ["ENV_VAR_NAME"]
models_csv = os.environ["SELECTED_MODELS"]

model_ids = [m.strip() for m in models_csv.split("\n") if m.strip()]

model_entries = []
for mid in model_ids:
    nl = mid.lower()
    entry = {
        "id": mid,
        "name": mid,
        "reasoning": any(k in nl for k in ["r1", "thinking", "reasoner"]),
        "input": ["text"],
        "contextWindow": 128000 if "128k" in nl else 65536,
        "maxTokens": 8192,
    }
    if any(k in nl for k in ["vision", "4.5v"]):
        entry["input"] = ["text", "image"]
    model_entries.append(entry)

if "models" not in config:
    config["models"] = {}
if "providers" not in config["models"]:
    config["models"]["providers"] = {}

# 使用 ${ENV_VAR} 引用而非明文 key
config["models"]["providers"][provider_name] = {
    "baseUrl": base_url,
    "apiKey": "${" + env_var_name + "}",
    "api": "openai-completions",
    "models": model_entries,
}
config["models"]["mode"] = "merge"

backup_path = config_path + f".bak-{provider_name}"
if os.path.exists(config_path):
    shutil.copy(config_path, backup_path)

with open(config_path, "w") as f:
    json.dump(config, f, indent=2, ensure_ascii=False)

print(f"OK:{len(model_entries)}:{backup_path}")
PYEOF

SETUP_RESULT=$(PROVIDER_NAME="${PROVIDER_NAME}" BASE_URL="${BASE_URL}" ENV_VAR_NAME="${ENV_VAR_NAME}" SELECTED_MODELS="${SELECTED_MODELS}" python3 "$_SETUP_SCRIPT" 2>&1)
rm -f "$_SETUP_SCRIPT"

# --- 写入环境变量到 shell profile ---
if [[ "$SETUP_RESULT" == OK:* ]]; then
    WRITTEN_COUNT=$(echo "$SETUP_RESULT" | cut -d: -f2)
    echo -e "  ${GREEN}成功写入 ${WRITTEN_COUNT} 个模型 (apiKey 引用 \$${ENV_VAR_NAME})${NC}"
    echo ""

    # 写入环境变量
    echo -e "${BOLD}写入 API Key 到环境变量...${NC}"
    _profile=$(detect_shell_profile)
    _write_env_to_profile "$_profile" "$ENV_VAR_NAME" "$API_KEY"
    echo ""
    echo -e "  ${DIM}提示: 新终端会自动加载。当前终端需执行: source ${_profile}${NC}"
    echo -e "  ${DIM}openclaw.json 中不存储明文 key，仅引用 \${${ENV_VAR_NAME}}${NC}"
    echo ""
else
    echo -e "${RED}配置写入失败:${NC}"
    echo "$SETUP_RESULT"
    exit 1
fi

# --- 验证写入 ---
echo -n "  验证 OpenClaw 识别... "
VERIFY_JSON=$(oc_exec "openclaw models list --all --json")
VERIFY_COUNT=$(echo "$VERIFY_JSON" | python3 -c "
import json,sys
try:
    d=json.loads(sys.stdin.read())
    prov=[m for m in d['models'] if m['key'].startswith('$PROVIDER_NAME/')]
    print(len(prov))
except:
    print(0)
" 2>/dev/null)

if [ -n "$VERIFY_COUNT" ] && [ "$VERIFY_COUNT" -gt 0 ] 2>/dev/null; then
    echo -e "${GREEN}OK — ${VERIFY_COUNT} 个模型已加载${NC}"
else
    echo -e "${YELLOW}未能验证，可能需要重启 gateway${NC}"
fi
echo ""

# =============================================
# Step 5-6: 设置默认模型 & Fallback & 重启
# =============================================
echo ""
if prompt_yn "是否设置默认模型和 Fallback?"; then
    if [ "$DO_WIZARD" = true ]; then
        print_step "5/6" "设置默认模型 & Fallback"
    fi
    # 复用独立功能
    # 获取当前状态
    OC_STATUS=$(oc_exec "openclaw models status --json")
    CURRENT_DEFAULT=$(echo "$OC_STATUS" | python3 -c "import json,sys; print(json.loads(sys.stdin.read()).get('defaultModel',''))" 2>/dev/null)
    CURRENT_FALLBACKS=$(echo "$OC_STATUS" | python3 -c "import json,sys; print(', '.join(json.loads(sys.stdin.read()).get('fallbacks',[])))" 2>/dev/null)

    echo ""
    echo -e "  当前默认模型: ${CYAN}${CURRENT_DEFAULT:-未设置}${NC}"
    if [ -n "$CURRENT_FALLBACKS" ]; then
        echo -e "  当前 fallback: ${DIM}${CURRENT_FALLBACKS}${NC}"
    fi
    echo ""

    # 获取所有可用模型 (不过滤 available 字段)
    ALL_AVAILABLE=$(echo "$VERIFY_JSON" | python3 -c "
import json,sys
d=json.loads(sys.stdin.read())
for m in sorted(d.get('models',[]), key=lambda x: x.get('key','')):
    print(m['key'])
" 2>/dev/null)

    AVAIL_COUNT=$(echo "$ALL_AVAILABLE" | sed '/^$/d' | wc -l | tr -d ' ')
    echo -e "  可用模型总数: ${GREEN}${AVAIL_COUNT}${NC}"
    echo ""

    if [ "$AVAIL_COUNT" -gt 0 ]; then
        # 按 provider 分组显示
        echo -e "${BOLD}可用模型:${NC}"
        AVAIL_ARRAY=()
        echo "$ALL_AVAILABLE" | python3 -c "
import sys
from collections import defaultdict
groups = defaultdict(list)
idx = 0
for line in sys.stdin:
    line = line.strip()
    if not line: continue
    prov = line.split('/')[0] if '/' in line else 'default'
    groups[prov].append((idx, line))
    idx += 1
for prov in sorted(groups.keys()):
    print(f'  --- {prov} ({len(groups[prov])}) ---')
    for i, m in groups[prov]:
        print(f'  {i+1:4d}) {m}')
" 2>/dev/null
        while IFS= read -r m; do
            [ -n "$m" ] && AVAIL_ARRAY+=("$m")
        done <<< "$ALL_AVAILABLE"
        echo ""

        if prompt_yn "是否更改默认模型?"; then
            printf "输入编号或模型全名: "
            read -r DEFAULT_INPUT
            if [[ "$DEFAULT_INPUT" =~ ^[0-9]+$ ]]; then
                idx=$((DEFAULT_INPUT - 1))
                if [ "$idx" -ge 0 ] && [ "$idx" -lt "${#AVAIL_ARRAY[@]}" ]; then
                    NEW_DEFAULT="${AVAIL_ARRAY[$idx]}"
                else
                    echo -e "${RED}编号超出范围${NC}"
                    NEW_DEFAULT=""
                fi
            else
                NEW_DEFAULT="$DEFAULT_INPUT"
            fi
            if [ -n "$NEW_DEFAULT" ]; then
                echo -n "  设置默认模型为 ${NEW_DEFAULT}... "
                SET_RESULT=$(oc_exec "openclaw models set '$(sanitize_input "${NEW_DEFAULT}")'")
                if echo "$SET_RESULT" | grep -qi "error\|fail"; then
                    echo -e "${RED}失败${NC}"
                    echo "  $SET_RESULT"
                else
                    echo -e "${GREEN}OK${NC}"
                fi
            fi
        fi
        echo ""

        if prompt_yn "是否配置 fallback 列表?"; then
            echo ""
            OC_STATUS_NEW=$(oc_exec "openclaw models status --json")
            NEW_DEFAULT=$(echo "$OC_STATUS_NEW" | python3 -c "import json,sys; print(json.loads(sys.stdin.read()).get('defaultModel',''))" 2>/dev/null)

            FB_ARRAY=()
            while IFS= read -r m; do
                [ -n "$m" ] || continue
                if [ "$m" = "$NEW_DEFAULT" ]; then continue; fi
                FB_ARRAY+=("$m")
            done <<< "$ALL_AVAILABLE"

            echo -e "  除默认模型外共 ${GREEN}${#FB_ARRAY[@]}${NC} 个模型可作为 fallback"
            echo ""
            echo -e "  ${CYAN}1)${NC} ${BOLD}全部设为 fallback${NC} ${GREEN}(推荐)${NC}"
            echo -e "     ${DIM}默认模型失败时自动切换到其他任意可用模型${NC}"
            echo -e "  ${CYAN}2)${NC} ${BOLD}手动选择${NC}"
            echo -e "     ${DIM}按编号指定 fallback 优先级顺序${NC}"
            echo ""
            FB_MODE=$(prompt_choice "请选择" "1")

            echo -n "  清除旧 fallback... "
            oc_exec "openclaw models fallbacks clear" >/dev/null 2>&1
            echo -e "${GREEN}OK${NC}"

            if [ "$FB_MODE" = "1" ]; then
                fb_ok=0; fb_fail=0
                echo -n "  添加 ${#FB_ARRAY[@]} 个 fallback 模型..."
                for fb_model in "${FB_ARRAY[@]}"; do
                    ADD_RESULT=$(oc_exec "openclaw models fallbacks add '$(sanitize_input "${fb_model}")'" 2>&1)
                    if echo "$ADD_RESULT" | grep -qi "error\|fail"; then
                        fb_fail=$((fb_fail + 1))
                    else
                        fb_ok=$((fb_ok + 1))
                    fi
                done
                echo ""
                echo -e "  ${GREEN}成功 ${fb_ok}${NC} / ${RED}失败 ${fb_fail}${NC}"
            else
                echo ""
                echo "可用模型 (输入编号，按优先级排序，逗号分隔):"
                echo ""
                fb_idx=0
                for m in "${FB_ARRAY[@]}"; do
                    fb_idx=$((fb_idx + 1))
                    printf "  %3d) %s\n" "$fb_idx" "$m"
                done
                echo ""
                printf "Fallback 顺序 (如 1,3,5,2): "
                read -r FB_SELECTIONS
                if [ -n "$FB_SELECTIONS" ]; then
                    for sel in $(echo "$FB_SELECTIONS" | tr ',' ' '); do
                        idx=$((sel - 1))
                        if [ "$idx" -ge 0 ] && [ "$idx" -lt "${#FB_ARRAY[@]}" ]; then
                            fb_model="${FB_ARRAY[$idx]}"
                            echo -n "  添加 fallback: ${fb_model}... "
                            ADD_RESULT=$(oc_exec "openclaw models fallbacks add '$(sanitize_input "${fb_model}")'")
                            if echo "$ADD_RESULT" | grep -qi "error\|fail"; then
                                echo -e "${RED}失败${NC}"
                            else
                                echo -e "${GREEN}OK${NC}"
                            fi
                        fi
                    done
                fi
            fi
        fi
    fi
fi
echo ""

# =============================================
# 最终: 显示状态 & 重启
# =============================================
print_header "配置完成 — 最终状态"

FINAL_STATUS=$(oc_exec "openclaw models status --json")
echo "$FINAL_STATUS" | python3 -c "
import json, sys
d = json.loads(sys.stdin.read())
print(f'  默认模型:  {d.get(\"defaultModel\", \"未设置\")}')
fb = d.get('fallbacks', [])
if fb:
    print(f'  Fallback ({len(fb)}):')
    for i, m in enumerate(fb, 1):
        print(f'    {i}. {m}')
else:
    print('  Fallback:  无')
" 2>/dev/null

echo ""

if prompt_yn "是否重启 Gateway 使配置生效?"; then
    echo ""
    restart_gateway
    sleep 3
    echo -n "  检查 health... "
    HEALTH=$(oc_exec "openclaw health" 2>/dev/null | head -1)
    if echo "$HEALTH" | grep -qi "ok\|running\|healthy"; then
        echo -e "${GREEN}${HEALTH}${NC}"
    else
        echo -e "${YELLOW}${HEALTH:-未能确认状态}${NC}"
        echo "  请手动运行: openclaw health"
    fi
fi

echo ""
echo -e "${GREEN}${BOLD}全部完成!${NC}"
echo ""
