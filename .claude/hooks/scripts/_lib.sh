#!/bin/bash
# Shared utilities for Xerus shell hooks

XERUS_WORKSPACE_ROOT="${XERUS_WORKSPACE_ROOT:?XERUS_WORKSPACE_ROOT must be set}"

# Validate AGENT_SLUG before it's used in any path construction
XERUS_AGENT_SLUG="${XERUS_AGENT_SLUG:-unknown}"
if [[ ! "$XERUS_AGENT_SLUG" =~ ^[a-zA-Z0-9._-]+$ ]]; then
  echo "ERROR: Invalid XERUS_AGENT_SLUG: $XERUS_AGENT_SLUG" >&2
  exit 1
fi

# Resolve Python binary (python3 on Linux/Daytona, python on Windows/MSYS)
PYTHON="${PYTHON:-$(command -v python3 2>/dev/null || command -v python 2>/dev/null || echo python3)}"
export PYTHON

# Ensure audit directory exists (idempotent)
mkdir -p "$XERUS_WORKSPACE_ROOT/.xerus" 2>/dev/null

# Emit a structured audit trail entry to hook-audit.jsonl
# Usage: audit "HookName"
audit() {
    local hook_name="$1"
    local agent="${XERUS_AGENT_SLUG:-unknown}"
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
# Usage: log_activity "event_name" "agent_slug"
log_activity() {
    local event="$1"
    local agent="${2:-${XERUS_AGENT_SLUG:-unknown}}"
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
