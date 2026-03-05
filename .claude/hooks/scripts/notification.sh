#!/bin/bash
# Notification hook: Route notifications to inbox
# Runs when SDK sends a notification

AGENT_SLUG="${XERUS_AGENT_SLUG:-unknown}"
WORKSPACE_ROOT="${WORKSPACE_ROOT:-/home/daytona}"
NOTIFICATION="${CLAUDE_NOTIFICATION:-}"

if [ -n "$NOTIFICATION" ]; then
  TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  FILENAME=$(date -u +%s)
  echo "{\"from\":\"system\",\"content\":\"$NOTIFICATION\",\"timestamp\":\"$TIMESTAMP\"}" > "$WORKSPACE_ROOT/agents/$AGENT_SLUG/inbox/$FILENAME.json"
fi
