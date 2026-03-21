#!/bin/bash
# Stop hook: Save partial progress on session interruption
# Task is NOT closed. Agent resumes from working.md on next wake.

AGENT_SLUG="${XERUS_AGENT_SLUG:-unknown}"
XERUS_WORKSPACE_ROOT="${XERUS_WORKSPACE_ROOT:?XERUS_WORKSPACE_ROOT must be set}"

source "$(dirname "$0")/_lib.sh"
audit "Stop"

# Save progress with interrupted flag
SCRIPT_DIR="$(dirname "$0")"
$PYTHON "$SCRIPT_DIR/save-progress.py" "$AGENT_SLUG" "$XERUS_WORKSPACE_ROOT" --interrupted 2>&1 || true

# Git commit whatever memory state exists
cd "$XERUS_WORKSPACE_ROOT/.memory" 2>/dev/null && {
  git add -A 2>/dev/null
  git diff --cached --quiet 2>/dev/null || git commit -m "stop: $AGENT_SLUG interrupted" 2>/dev/null
}

log_activity "stop" "$AGENT_SLUG"
