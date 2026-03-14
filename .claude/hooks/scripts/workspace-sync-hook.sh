#!/bin/bash
# Hook: PostToolUse - Workspace Sync Trigger
# Detects writes to sync-relevant paths and queues a sync request.
#
# Event: PostToolUse
# Matcher: Write|Edit

XERUS_WORKSPACE_ROOT="${XERUS_WORKSPACE_ROOT:?XERUS_WORKSPACE_ROOT must be set}"
QUEUE_FILE="$XERUS_WORKSPACE_ROOT/.claude/sync-queue.jsonl"
TOOL_NAME="${CLAUDE_TOOL_NAME:-unknown}"
AGENT_SLUG="${XERUS_AGENT_SLUG:-unknown}"

source "$(dirname "$0")/_lib.sh"
audit "WorkspaceSyncHook"

case "$TOOL_NAME" in
  Write|Edit)
    FILE_PATH=""
    if command -v jq &>/dev/null; then
      HOOK_INPUT=$(cat 2>/dev/null)
      if [ -n "$HOOK_INPUT" ]; then
        FILE_PATH=$(echo "$HOOK_INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
      fi
    fi
    FILE_PATH="${FILE_PATH:-${CLAUDE_TOOL_FILE_PATH:-}}"

    if [ -z "$FILE_PATH" ]; then
      exit 0
    fi

    # Check if path is sync-relevant
    SYNC_TYPE=""
    case "$FILE_PATH" in
      */.claude/skills/*/SKILL.md)
        SYNC_TYPE="skill_change"
        ;;
      */shared/knowledge/*.md)
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
