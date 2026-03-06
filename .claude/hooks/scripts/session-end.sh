#!/bin/bash
# SessionEnd hook: Git commit memory, update STATUS.md, persist state
# Runs when agent session ends

AGENT_SLUG="${XERUS_AGENT_SLUG:-unknown}"
WORKSPACE_ROOT="${WORKSPACE_ROOT:-/home/daytona}"
MEMORY_ROOT="$WORKSPACE_ROOT/.memory"

# Git commit memory changes
cd "$MEMORY_ROOT" 2>/dev/null && {
  git add -A 2>/dev/null
  git diff --cached --quiet 2>/dev/null || git commit -m "session-end: $AGENT_SLUG at $(date -u +%Y-%m-%dT%H:%M:%SZ)" 2>/dev/null
}

echo "{\"event\":\"session_end\",\"agent\":\"$AGENT_SLUG\",\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}" >> "$WORKSPACE_ROOT/shared/activity.jsonl"
