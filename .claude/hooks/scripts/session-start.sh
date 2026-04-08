#!/bin/bash
# SessionStart hook: Initialize workspace, inject task context
# Runs when a new agent session begins

AGENT_SLUG="${XERUS_AGENT_SLUG:-unknown}"
XERUS_WORKSPACE_ROOT="${XERUS_WORKSPACE_ROOT:?XERUS_WORKSPACE_ROOT must be set}"

source "$(dirname "$0")/_lib.sh"
audit "SessionStart"

# Resolve agent's directory and memory location
AGENT_DIR=$(resolve_agent_dir "$AGENT_SLUG")
MEMORY_DIR=$(resolve_agent_memory_dir "$AGENT_SLUG")

# Ensure memory directory exists for this agent
mkdir -p "$MEMORY_DIR"

# Initialize company.db + workspace.db if needed
"$(dirname "$0")/init-db.sh"

# Ensure Python MCP package is installed (required by IPC server)
if ! python3 -c "import mcp" 2>/dev/null; then
  pip3 install --break-system-packages --quiet mcp 2>/dev/null &
fi

# Ensure scheduler daemon is running (idempotent)
# The daemon polls workspace.db schedules table every 30s and spawns CLI processes
SCHEDULER_PID_FILE="$XERUS_WORKSPACE_ROOT/.xerus/runner/scheduler.pid"
SCHEDULER_SCRIPT="$XERUS_WORKSPACE_ROOT/.xerus/runner/scheduler.ts"
SCHEDULER_LOG="$XERUS_WORKSPACE_ROOT/.xerus/runner/scheduler.log"

if [ -f "$SCHEDULER_SCRIPT" ]; then
  SCHEDULER_RUNNING=false
  if [ -f "$SCHEDULER_PID_FILE" ]; then
    SCHEDULER_PID=$(cat "$SCHEDULER_PID_FILE" 2>/dev/null)
    if [ -n "$SCHEDULER_PID" ] && kill -0 "$SCHEDULER_PID" 2>/dev/null; then
      SCHEDULER_RUNNING=true
    fi
  fi

  if [ "$SCHEDULER_RUNNING" = false ]; then
    if command -v bun &>/dev/null; then
      cd "$XERUS_WORKSPACE_ROOT" && nohup bun run "$SCHEDULER_SCRIPT" >> "$SCHEDULER_LOG" 2>&1 &
      SCHEDULER_PID=$!
      echo "$SCHEDULER_PID" > "$SCHEDULER_PID_FILE"
      log_activity "scheduler_started" "system" "pid=$SCHEDULER_PID"
    fi
  fi
fi

# Touch working.md if it doesn't exist
if [ ! -f "$MEMORY_DIR/working.md" ]; then
  cat > "$MEMORY_DIR/working.md" <<'WORKING'
# Working Memory

No previous session state.
WORKING
fi

# Cache channel path for other hooks to reuse
if [ -n "$AGENT_DIR" ] && [ -d "$AGENT_DIR" ]; then
  CHANNEL_REL=$(resolve_channel_dir "$AGENT_SLUG")
  if [ -n "$CHANNEL_REL" ]; then
    echo "$CHANNEL_REL" > "$AGENT_DIR/.channel-path"
  fi
fi

# Log session start to activity
log_activity "session_start" "$AGENT_SLUG"

# Generate task context via standalone Python script
# Scans ALL channel boards for tasks assigned to this agent
TASK_CONTEXT="$MEMORY_DIR/.task-context.md"
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
