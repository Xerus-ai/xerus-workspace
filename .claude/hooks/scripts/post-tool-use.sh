#!/bin/bash
# PostToolUse hook: Log file_write events to activity.jsonl for metadata sync
# Runs after each tool execution.
#
# Hook I/O contract (Claude Code):
# - Input arrives as JSON on stdin: {tool_name, tool_input, tool_response, ...}
#   (There are NO CLAUDE_TOOL_NAME / CLAUDE_TOOL_INPUT_* env vars.)
# - PostToolUse cannot block — the tool already ran. Always exit 0.

AGENT_SLUG="${XERUS_AGENT_SLUG:-}"
XERUS_WORKSPACE_ROOT="${XERUS_WORKSPACE_ROOT:?XERUS_WORKSPACE_ROOT must be set}"

source "$(dirname "$0")/_lib.sh"
audit "PostToolUse"
parse_hook_input

# If tool was Write/Edit, log a file_write event for metadata sync
case "$TOOL_NAME" in
  Write|Edit)
    if [ -n "$FILE_PATH" ]; then
      # Fail-fast: never attribute a file_write to a missing/"unknown" agent.
      # resolve_activity_agent emits a loud error and returns non-zero if the
      # launch path forgot to inject XERUS_AGENT_SLUG.
      AGENT_SLUG=$(resolve_activity_agent "file_write") || exit 0
      TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
      if command -v jq &>/dev/null; then
        jq -n --arg event "file_write" --arg path "$FILE_PATH" --arg agent "$AGENT_SLUG" --arg ts "$TIMESTAMP" \
          '{event: $event, path: $path, agent: $agent, timestamp: $ts}' >> "$XERUS_WORKSPACE_ROOT/data/activity.jsonl"
      else
        SAFE_PATH=$(printf '%s' "$FILE_PATH" | sed 's/\\/\\\\/g; s/"/\\"/g')
        echo "{\"event\":\"file_write\",\"path\":\"$SAFE_PATH\",\"agent\":\"$AGENT_SLUG\",\"timestamp\":\"$TIMESTAMP\"}" >> "$XERUS_WORKSPACE_ROOT/data/activity.jsonl"
      fi
    fi
    ;;
esac

exit 0
