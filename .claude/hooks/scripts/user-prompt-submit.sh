#!/bin/bash
# UserPromptSubmit hook: Pause check + skill discovery + context gathering
# Runs before the agent processes a user prompt or heartbeat trigger.
# Prepares a warm start: matched skills, previous session state, inbox messages.

AGENT_SLUG="${XERUS_AGENT_SLUG:-unknown}"
XERUS_WORKSPACE_ROOT="${XERUS_WORKSPACE_ROOT:?XERUS_WORKSPACE_ROOT must be set}"

source "$(dirname "$0")/_lib.sh"
audit "UserPromptSubmit"

# Check if agent is paused (HITL pause state)
PAUSE_FILE="$XERUS_WORKSPACE_ROOT/agents/$AGENT_SLUG/.paused"
if [ -f "$PAUSE_FILE" ]; then
  echo "Agent $AGENT_SLUG is paused. Resume via platform.resume_execution."
  exit 1
fi

# Gather session context: skill matching, memory, inbox, entities
SCRIPT_DIR="$(dirname "$0")"
$PYTHON "$SCRIPT_DIR/gather-session-context.py" "$AGENT_SLUG" "$XERUS_WORKSPACE_ROOT" 2>&1 || true

log_activity "prompt_received" "$AGENT_SLUG"
