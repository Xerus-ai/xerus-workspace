#!/bin/bash
# SessionStart hook: Initialize workspace, inject task context
# Runs when a new agent session begins

AGENT_SLUG="${XERUS_AGENT_SLUG:-unknown}"
XERUS_WORKSPACE_ROOT="${XERUS_WORKSPACE_ROOT:?XERUS_WORKSPACE_ROOT must be set}"

source "$(dirname "$0")/_lib.sh"
audit "SessionStart"

# Ensure memory directory exists for this agent
mkdir -p "$XERUS_WORKSPACE_ROOT/.memory/agents/$AGENT_SLUG"

# Initialize company.db if needed
"$(dirname "$0")/init-db.sh"

# Touch working.md if it doesn't exist
if [ ! -f "$XERUS_WORKSPACE_ROOT/.memory/agents/$AGENT_SLUG/working.md" ]; then
  cat > "$XERUS_WORKSPACE_ROOT/.memory/agents/$AGENT_SLUG/working.md" <<'WORKING'
# Working Memory

No previous session state.
WORKING
fi

# Cache channel path for other hooks to reuse
AGENT_CLAUDE="$XERUS_WORKSPACE_ROOT/agents/$AGENT_SLUG/CLAUDE.md"
if [ -f "$AGENT_CLAUDE" ]; then
  CHANNEL_REL=$(resolve_channel_dir "$AGENT_SLUG")
  if [ -n "$CHANNEL_REL" ]; then
    echo "$CHANNEL_REL" > "$XERUS_WORKSPACE_ROOT/agents/$AGENT_SLUG/.channel-path"
  fi
fi

# Log session start to activity
log_activity "session_start" "$AGENT_SLUG"

# Generate task context via standalone Python script
# Scans ALL channel boards for tasks assigned to this agent
TASK_CONTEXT="$XERUS_WORKSPACE_ROOT/.memory/agents/$AGENT_SLUG/.task-context.md"
SCRIPT_DIR="$(dirname "$0")"

$PYTHON "$SCRIPT_DIR/generate-task-context.py" \
  "$AGENT_SLUG" \
  "$XERUS_WORKSPACE_ROOT" \
  "$TASK_CONTEXT" 2>&1 || {
  # On Python failure, write diagnostic context
  cat > "$TASK_CONTEXT" <<ERRCTX
# Task Context -- $AGENT_SLUG
Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)

## Status: ERROR
Task context generation failed. Check hook logs.
Read your CLAUDE.md and working.md for self-directed work.
ERRCTX
}
