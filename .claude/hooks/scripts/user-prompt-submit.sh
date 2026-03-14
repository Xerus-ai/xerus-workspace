#!/bin/bash
# UserPromptSubmit hook: Validate input, check HITL pause state
# Runs before processing user prompt

AGENT_SLUG="${XERUS_AGENT_SLUG:-unknown}"
WORKSPACE_ROOT="${WORKSPACE_ROOT:-/home/daytona}"

# Audit trail for shell hook observability
mkdir -p "$WORKSPACE_ROOT/.xerus"
echo "{\"hook\":\"UserPromptSubmit\",\"agent\":\"$AGENT_SLUG\",\"ts\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"ok\":true}" >> "$WORKSPACE_ROOT/.xerus/hook-audit.jsonl"

# Check if agent is paused (HITL pause state)
PAUSE_FILE="$WORKSPACE_ROOT/agents/$AGENT_SLUG/.paused"
if [ -f "$PAUSE_FILE" ]; then
  echo "Agent $AGENT_SLUG is paused. Resume via platform.resume_execution before continuing."
  exit 1
fi
