#!/bin/bash
# SubagentStop hook: Log subagent completion, save any partial state

AGENT_SLUG="${XERUS_AGENT_SLUG:-unknown}"
XERUS_WORKSPACE_ROOT="${XERUS_WORKSPACE_ROOT:?XERUS_WORKSPACE_ROOT must be set}"

source "$(dirname "$0")/_lib.sh"
audit "SubagentStop"

# Save progress (subagent may have been working on a subtask)
SCRIPT_DIR="$(dirname "$0")"
$PYTHON "$SCRIPT_DIR/save-progress.py" "$AGENT_SLUG" "$XERUS_WORKSPACE_ROOT" 2>&1 || true

log_activity "subagent_stop" "$AGENT_SLUG"
