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

# Write shift handoff if agent has a channel
AGENT_DIR=$(resolve_agent_dir "$AGENT_SLUG")
if [ -n "$AGENT_DIR" ] && [ -f "$AGENT_DIR/.channel-path" ]; then
  CHANNEL_REL=$(cat "$AGENT_DIR/.channel-path" 2>/dev/null)
  if [ -n "$CHANNEL_REL" ]; then
    HANDOFF_DIR="$XERUS_WORKSPACE_ROOT/$CHANNEL_REL/.channel/state/handoffs"
    $PYTHON "$SCRIPT_DIR/write-handoff.py" "$AGENT_SLUG" "$XERUS_WORKSPACE_ROOT" "$HANDOFF_DIR" 2>&1 || true
  fi
fi

# Git commit all memory changes
cd "$MEMORY_ROOT" 2>/dev/null && {
  git add -A 2>/dev/null
  git diff --cached --quiet 2>/dev/null || git commit -m "session-end: $AGENT_SLUG" 2>/dev/null
}

# Trigger memory indexing for changed files after commit
cd "$MEMORY_ROOT" 2>/dev/null && {
  CHANGED=$(git diff --name-only HEAD~1 HEAD 2>/dev/null || echo "")
  if [ -n "$CHANGED" ]; then
    mkdir -p "$XERUS_WORKSPACE_ROOT/.xerus/state"
    echo "$CHANGED" > "$XERUS_WORKSPACE_ROOT/.xerus/state/pending-index.txt"
  fi
}

# Run data integrity check
bash "$SCRIPT_DIR/data-integrity-check.sh" 2>&1 || true

log_activity "session_end" "$AGENT_SLUG"
