#!/bin/bash
# PostToolUse hook: Trigger metadata_sync for file writes, update billing
# Runs after each tool execution
#
# SDK hook input is passed as JSON on stdin. CLAUDE_TOOL_NAME is set by the runner.
# File path extraction: the SDK passes tool_input as part of the hook JSON payload.
# We parse it from stdin if available, falling back to env var.

TOOL_NAME="${CLAUDE_TOOL_NAME:-unknown}"
AGENT_SLUG="${XERUS_AGENT_SLUG:-unknown}"
XERUS_WORKSPACE_ROOT="${XERUS_WORKSPACE_ROOT:?XERUS_WORKSPACE_ROOT must be set}"

source "$(dirname "$0")/_lib.sh"
audit "PostToolUse"

# If tool was Write/Edit, trigger metadata sync for known paths
case "$TOOL_NAME" in
  Write|Edit)
    # Try to extract file_path from hook JSON input (stdin), fallback to env var
    FILE_PATH=""
    if command -v jq &>/dev/null; then
      HOOK_INPUT=$(cat 2>/dev/null)
      if [ -n "$HOOK_INPUT" ]; then
        FILE_PATH=$(echo "$HOOK_INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
      fi
    fi
    FILE_PATH="${FILE_PATH:-${CLAUDE_TOOL_FILE_PATH:-}}"

    if [ -n "$FILE_PATH" ]; then
      TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
      if command -v jq &>/dev/null; then
        jq -n --arg event "file_write" --arg path "$FILE_PATH" --arg agent "$AGENT_SLUG" --arg ts "$TIMESTAMP" \
          '{event: $event, path: $path, agent: $agent, timestamp: $ts}' >> "$XERUS_WORKSPACE_ROOT/shared/activity.jsonl"
      else
        SAFE_PATH=$(printf '%s' "$FILE_PATH" | sed 's/\\/\\\\/g; s/"/\\"/g')
        echo "{\"event\":\"file_write\",\"path\":\"$SAFE_PATH\",\"agent\":\"$AGENT_SLUG\",\"timestamp\":\"$TIMESTAMP\"}" >> "$XERUS_WORKSPACE_ROOT/shared/activity.jsonl"
      fi
    fi
    ;;
esac
