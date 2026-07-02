#!/bin/bash
# Shared utilities for Xerus shell hooks

XERUS_WORKSPACE_ROOT="${XERUS_WORKSPACE_ROOT:?XERUS_WORKSPACE_ROOT must be set}"

# Agent identity comes ONLY from XERUS_AGENT_SLUG, injected by the backend CLI
# launch path (daytona-runner.ts buildSessionCommand). There is deliberately NO
# "unknown" fallback: a missing value is a launch-path bug that must surface
# loudly (see resolve_activity_agent) instead of silently mislabelling activity.
# Validate the format up front when present so path construction stays safe.
if [ -n "${XERUS_AGENT_SLUG:-}" ] && [[ ! "$XERUS_AGENT_SLUG" =~ ^[a-zA-Z0-9._-]+$ ]]; then
  echo "ERROR [xerus-hook]: Invalid XERUS_AGENT_SLUG: '$XERUS_AGENT_SLUG'" >&2
  exit 1
fi

# Resolve Python binary (python3 on Linux/Daytona, python on Windows/MSYS)
PYTHON="${PYTHON:-$(command -v python3 2>/dev/null || command -v python 2>/dev/null || echo python3)}"
export PYTHON

# Parse Claude Code hook input from stdin JSON.
#
# Hook I/O contract (Claude Code):
# - Input arrives as JSON on stdin: {tool_name, tool_input, tool_use_id, ...}
#   (There are NO CLAUDE_TOOL_NAME / CLAUDE_TOOL_INPUT_* env vars.)
# - Exit 2 BLOCKS a PreToolUse tool call and feeds stderr back to the model.
#   Exit 0 allows the call. Exit 1 is a non-blocking error and does NOT block.
# - PostToolUse hooks cannot block (the tool already ran).
#
# Sets globals: TOOL_NAME, TOOL_USE_ID, BASH_CMD, FILE_PATH, QUESTION, QUESTIONS
# Safe on empty or malformed stdin: defaults stay in place.
parse_hook_input() {
    TOOL_NAME="unknown"
    TOOL_USE_ID=""
    BASH_CMD=""
    FILE_PATH=""
    QUESTION=""
    QUESTIONS="null"
    local hook_input
    hook_input=$(cat 2>/dev/null || true)
    if [ -n "$hook_input" ]; then
        eval "$(printf '%s' "$hook_input" | $PYTHON -c "
import json, sys, shlex
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)
ti = d.get('tool_input') or {}
def emit(k, v):
    print(k + '=' + shlex.quote('' if v is None else str(v)))
emit('TOOL_NAME', d.get('tool_name') or 'unknown')
emit('TOOL_USE_ID', d.get('tool_use_id') or '')
emit('BASH_CMD', ti.get('command') or '')
emit('FILE_PATH', ti.get('file_path') or '')
emit('QUESTION', ti.get('question') or '')
qs = ti.get('questions')
emit('QUESTIONS', json.dumps(qs) if qs is not None else 'null')
" 2>/dev/null || true)"
    fi
    return 0
}

# Ensure audit directory exists (idempotent)
mkdir -p "$XERUS_WORKSPACE_ROOT/.xerus" 2>/dev/null

# Resolve the agent identity for an activity/audit write. Fail-fast: identity
# comes ONLY from XERUS_AGENT_SLUG (injected by the backend CLI launch path in
# daytona-runner.ts buildSessionCommand). There is deliberately NO "unknown"
# fallback -- a missing value means a launch path spawned the CLI without the
# env var, and we refuse to pollute the activity feed with a bogus agent.
#
# Args:
#   $1 - context label used in the error message (hook name or event name)
#   $2 - optional explicit slug (e.g. "system" for non-agent events); when
#        empty the XERUS_AGENT_SLUG env var is used.
# On success: prints the validated slug to stdout, returns 0.
# On failure: prints nothing to stdout, emits a loud error to stderr, returns 1.
resolve_activity_agent() {
    local context="$1"
    local slug="${2:-${XERUS_AGENT_SLUG:-}}"
    if [ -z "$slug" ]; then
        {
            echo "ERROR [xerus-hook]: refusing to write activity ('$context') without an agent identity."
            echo "  XERUS_AGENT_SLUG is unset/empty: the CLI launch path that spawned this"
            echo "  session did not inject it. Fix the launcher (the backend injects it in"
            echo "  daytona-runner.ts buildSessionCommand); do NOT fall back to 'unknown'."
        } >&2
        return 1
    fi
    if [[ ! "$slug" =~ ^[a-zA-Z0-9._-]+$ ]]; then
        echo "ERROR [xerus-hook]: refusing to write activity ('$context'): invalid agent slug '$slug'." >&2
        return 1
    fi
    printf '%s' "$slug"
}

# Emit a structured audit trail entry to hook-audit.jsonl
# Usage: audit "HookName"
# Fail-fast: refuses to write (and returns non-zero) if no valid agent identity.
audit() {
    local hook_name="$1"
    local agent
    agent=$(resolve_activity_agent "$hook_name") || return 1
    # Use printf for timestamp to avoid forking date subprocess
    local ts
    if printf -v ts '%(%Y-%m-%dT%H:%M:%SZ)T' -1 2>/dev/null; then
        : # bash 4.2+ built-in worked
    else
        ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    fi
    printf '{"hook":"%s","agent":"%s","ts":"%s","ok":true}\n' \
        "$hook_name" "$agent" "$ts" >> "$XERUS_WORKSPACE_ROOT/.xerus/hook-audit.jsonl"
}

# Log an activity event to data/activity.jsonl
# Usage: log_activity "event_name" ["agent_slug"]
# Fail-fast: refuses to write (and returns non-zero) if no valid agent identity.
log_activity() {
    local event="$1"
    local agent
    agent=$(resolve_activity_agent "$event" "$2") || return 1
    local ts
    if printf -v ts '%(%Y-%m-%dT%H:%M:%SZ)T' -1 2>/dev/null; then
        :
    else
        ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    fi
    printf '{"event":"%s","agent":"%s","timestamp":"%s"}\n' \
        "$event" "$agent" "$ts" >> "$XERUS_WORKSPACE_ROOT/data/activity.jsonl"
}

# Resolve agent's primary channel directory (relative to workspace root)
# Usage: resolve_channel_dir "agent-slug"
# Returns: "projects/domain/channels/channel" or empty string
#
# Architecture: Agents live at workspace root (agents/{slug}/)
# They are ASSIGNED to channels via config.json primary_channel field.
resolve_channel_dir() {
    local slug="$1"

    # Workspace-level agents (orchestrators) don't have a single channel
    if [ -d "$XERUS_WORKSPACE_ROOT/.claude/agents/$slug" ]; then
        echo ""
        return
    fi

    # Read primary_channel from agent's config.json
    local config_file="$XERUS_WORKSPACE_ROOT/agents/$slug/config.json"
    if [ -f "$config_file" ]; then
        local primary_channel
        primary_channel=$($PYTHON -c "
import json, sys, glob, os
try:
    with open(sys.argv[1]) as f:
        config = json.load(f)
    pc = config.get('primary_channel', '')
    domain = config.get('domain', '')
    ws = sys.argv[2]
    if pc and domain:
        print('projects/' + domain + '/channels/' + pc)
    elif pc:
        matches = glob.glob(ws + '/projects/*/channels/' + pc)
        if matches:
            print(os.path.relpath(matches[0], ws))
except Exception:
    pass
" "$config_file" "$XERUS_WORKSPACE_ROOT" 2>/dev/null)
        echo "$primary_channel"
        return
    fi

    echo ""
}

# Get agent's full path
# Usage: resolve_agent_dir "agent-slug"
# Returns: absolute path to agent directory
#
# Architecture:
#   - Workspace orchestrators: .claude/agents/{slug}/
#   - All other agents: agents/{slug}/
resolve_agent_dir() {
    local slug="$1"

    # Workspace-level orchestrators (xerus-master, xerus-cto)
    if [ -d "$XERUS_WORKSPACE_ROOT/.claude/agents/$slug" ]; then
        echo "$XERUS_WORKSPACE_ROOT/.claude/agents/$slug"
        return
    fi

    # Standard agents at workspace root
    if [ -d "$XERUS_WORKSPACE_ROOT/agents/$slug" ]; then
        echo "$XERUS_WORKSPACE_ROOT/agents/$slug"
        return
    fi

    echo ""
}

# Get agent's memory directory
# Usage: resolve_agent_memory_dir "agent-slug"
# Returns: absolute path to agent's .memory directory
#
# Architecture: All agent memory lives at .memory/agents/{slug}/
# (Not channel-scoped, since agents can work across multiple channels)
resolve_agent_memory_dir() {
    local slug="$1"
    echo "$XERUS_WORKSPACE_ROOT/.memory/agents/$slug"
}

# Validate a path stays within the workspace boundary
# Usage: validate_workspace_path "/resolved/path"
# Returns 0 if safe, 1 if path escapes workspace
validate_workspace_path() {
    local check_path="$1"
    local resolved
    resolved=$(realpath -m "$check_path" 2>/dev/null || echo "$check_path")
    local ws_resolved
    ws_resolved=$(realpath -m "$XERUS_WORKSPACE_ROOT" 2>/dev/null || echo "$XERUS_WORKSPACE_ROOT")
    case "$resolved" in
        "$ws_resolved"/*) return 0 ;;
        "$ws_resolved") return 0 ;;
        *) return 1 ;;
    esac
}

# Validate that a string contains only safe characters (alphanumeric, hyphen, underscore, dot)
# Usage: validate_safe_id "$SOME_ID"
# Returns 0 if safe, 1 if contains unsafe characters
validate_safe_id() {
    local id="$1"
    if [[ "$id" =~ ^[a-zA-Z0-9._-]+$ ]]; then
        return 0
    else
        return 1
    fi
}
