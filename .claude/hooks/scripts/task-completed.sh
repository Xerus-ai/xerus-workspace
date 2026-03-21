#!/bin/bash
# TaskCompleted hook: Log completion, trigger dependency cascade
# When a task closes, find downstream agents whose tasks are now unblocked
# and write coordination messages to their inboxes + regenerate their .task-context.md

AGENT_SLUG="${XERUS_AGENT_SLUG:-unknown}"
XERUS_WORKSPACE_ROOT="${XERUS_WORKSPACE_ROOT:?XERUS_WORKSPACE_ROOT must be set}"

source "$(dirname "$0")/_lib.sh"
audit "TaskCompleted"

log_activity "task_completed" "$AGENT_SLUG"

# Run dependency cascade: find unblocked agents and notify them
SCRIPT_DIR="$(dirname "$0")"
$PYTHON "$SCRIPT_DIR/cascade-unblocked.py" \
  "$AGENT_SLUG" \
  "$XERUS_WORKSPACE_ROOT" 2>&1 || true
