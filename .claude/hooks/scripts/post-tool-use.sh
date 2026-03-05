#!/bin/bash
# PostToolUse hook: Trigger metadata_sync for file writes, update billing
# Runs after each tool execution

TOOL_NAME="${CLAUDE_TOOL_NAME:-unknown}"
AGENT_SLUG="${XERUS_AGENT_SLUG:-unknown}"
WORKSPACE_ROOT="${WORKSPACE_ROOT:-/home/daytona}"

# If tool was Write/Edit, trigger metadata sync for known paths
case "$TOOL_NAME" in
  Write|Edit)
    FILE_PATH="${CLAUDE_TOOL_FILE_PATH:-}"
    if [ -n "$FILE_PATH" ]; then
      echo "{\"event\":\"file_write\",\"path\":\"$FILE_PATH\",\"agent\":\"$AGENT_SLUG\",\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}" >> "$WORKSPACE_ROOT/shared/activity.jsonl"
    fi
    ;;
esac
