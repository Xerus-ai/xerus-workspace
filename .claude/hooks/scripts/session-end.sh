#!/bin/bash
# SessionEnd hook: Summary, memory commit, housekeeping, dashboard
# Runs when agent session ends normally

AGENT_SLUG="${XERUS_AGENT_SLUG:-unknown}"
XERUS_WORKSPACE_ROOT="${XERUS_WORKSPACE_ROOT:?XERUS_WORKSPACE_ROOT must be set}"
MEMORY_ROOT="$XERUS_WORKSPACE_ROOT/.memory"

source "$(dirname "$0")/_lib.sh"
audit "SessionEnd"

# Run cleanup: session summary, expertise update, dashboard, housekeeping
SCRIPT_DIR="$(dirname "$0")"
$PYTHON "$SCRIPT_DIR/session-end-cleanup.py" "$AGENT_SLUG" "$XERUS_WORKSPACE_ROOT" 2>&1 || true

# Git commit all memory changes
cd "$MEMORY_ROOT" 2>/dev/null && {
  git add -A 2>/dev/null
  git diff --cached --quiet 2>/dev/null || git commit -m "session-end: $AGENT_SLUG" 2>/dev/null
}

# Run data integrity check
bash "$SCRIPT_DIR/data-integrity-check.sh" 2>&1 || true

log_activity "session_end" "$AGENT_SLUG"
