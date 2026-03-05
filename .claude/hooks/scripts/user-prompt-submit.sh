#!/bin/bash
# UserPromptSubmit hook: Validate input, check HITL pause state
# Runs before processing user prompt

AGENT_SLUG="${XERUS_AGENT_SLUG:-unknown}"
WORKSPACE_ROOT="${WORKSPACE_ROOT:-/home/daytona}"

# Check if agent is paused (HITL pause state)
PAUSE_FILE="$WORKSPACE_ROOT/agents/$AGENT_SLUG/.paused"
if [ -f "$PAUSE_FILE" ]; then
  echo "Agent $AGENT_SLUG is paused. Resume via platform.resume_execution before continuing."
  exit 1
fi
