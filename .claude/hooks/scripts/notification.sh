#!/bin/bash
# Notification hook: Route notifications to inbox
# Runs when SDK sends a notification

AGENT_SLUG="${XERUS_AGENT_SLUG:-unknown}"
XERUS_WORKSPACE_ROOT="${XERUS_WORKSPACE_ROOT:?XERUS_WORKSPACE_ROOT must be set}"
NOTIFICATION="${CLAUDE_NOTIFICATION:-}"

source "$(dirname "$0")/_lib.sh"
audit "Notification"

if [ -n "$NOTIFICATION" ]; then
  TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  FILENAME=$(date -u +%s%N 2>/dev/null || date -u +%s)-$$
  INBOX_DIR="$XERUS_WORKSPACE_ROOT/agents/$AGENT_SLUG/inbox"
  mkdir -p "$INBOX_DIR"

  # Use jq if available for safe JSON encoding, fallback to printf escaping
  if command -v jq &>/dev/null; then
    jq -n --arg from "system" --arg content "$NOTIFICATION" --arg ts "$TIMESTAMP" \
      '{from: $from, content: $content, timestamp: $ts}' > "$INBOX_DIR/$FILENAME.json"
  else
    # Escape backslashes, double quotes, and control characters
    SAFE_NOTIFICATION=$(printf '%s' "$NOTIFICATION" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\t/\\t/g; s/\r/\\r/g' | tr '\n' ' ')
    echo "{\"from\":\"system\",\"content\":\"$SAFE_NOTIFICATION\",\"timestamp\":\"$TIMESTAMP\"}" > "$INBOX_DIR/$FILENAME.json"
  fi
fi
