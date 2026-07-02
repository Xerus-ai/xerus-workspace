#!/bin/bash
# Hook: PostToolUse - Workspace Sync Trigger
# Detects writes to sync-relevant paths and queues a sync request.
#
# Event: PostToolUse
# Matcher: Write|Edit
#
# Hook input arrives as JSON on stdin, parsed by parse_hook_input in _lib.sh.
# (There are NO CLAUDE_TOOL_NAME / CLAUDE_TOOL_INPUT_* env vars.)

XERUS_WORKSPACE_ROOT="${XERUS_WORKSPACE_ROOT:?XERUS_WORKSPACE_ROOT must be set}"
QUEUE_FILE="$XERUS_WORKSPACE_ROOT/.claude/sync-queue.jsonl"
AGENT_SLUG="${XERUS_AGENT_SLUG:-unknown}"

source "$(dirname "$0")/_lib.sh"
audit "WorkspaceSyncHook"
parse_hook_input

case "$TOOL_NAME" in
  Write|Edit)
    if [ -z "$FILE_PATH" ]; then
      exit 0
    fi

    # Check if path is sync-relevant
    SYNC_TYPE=""
    case "$FILE_PATH" in
      */.claude/skills/*/SKILL.md)
        SYNC_TYPE="skill_change"
        ;;
      */drive/*.md)
        SYNC_TYPE="knowledge_change"
        ;;
      */projects/*/channels/*/CLAUDE.md)
        SYNC_TYPE="channel_change"
        ;;
      */agents/*/config.json)
        SYNC_TYPE="agent_change"
        ;;
      */agents/index.json)
        SYNC_TYPE="roster_change"
        ;;
    esac

    if [ -n "$SYNC_TYPE" ]; then
      TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
      if command -v jq &>/dev/null; then
        jq -n \
          --arg type "$SYNC_TYPE" \
          --arg path "$FILE_PATH" \
          --arg agent "$AGENT_SLUG" \
          --arg ts "$TIMESTAMP" \
          '{type: $type, path: $path, triggered_by: $agent, timestamp: $ts}' >> "$QUEUE_FILE"
      else
        SAFE_PATH=$(printf '%s' "$FILE_PATH" | sed 's/\\/\\\\/g; s/"/\\"/g')
        echo "{\"type\":\"$SYNC_TYPE\",\"path\":\"$SAFE_PATH\",\"triggered_by\":\"$AGENT_SLUG\",\"timestamp\":\"$TIMESTAMP\"}" >> "$QUEUE_FILE"
      fi
    fi
    ;;
esac

exit 0
