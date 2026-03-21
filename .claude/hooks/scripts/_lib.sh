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

# Log an activity event to shared/activity.jsonl
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
        "$event" "$agent" "$ts" >> "$XERUS_WORKSPACE_ROOT/shared/activity.jsonl"
}

# Resolve agent's primary channel directory (relative to workspace root)
# Usage: resolve_channel_dir "agent-slug"
# Returns: "projects/domain/channels/channel" or empty string
resolve_channel_dir() {
    local slug="$1"
    local claude_file="$XERUS_WORKSPACE_ROOT/agents/$slug/CLAUDE.md"
    if [ ! -f "$claude_file" ]; then
        echo ""
        return
    fi
    local rel
    rel=$(grep "Primary:" "$claude_file" 2>/dev/null | sed 's/.*Primary:[[:space:]]*//' | sed 's/[[:space:]]*$//' | sed 's/\/$//' || true)
    echo "$rel"
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
