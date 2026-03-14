#!/bin/bash
# SessionEnd hook: Git commit memory, update STATUS.md, persist state
# Runs when agent session ends

AGENT_SLUG="${XERUS_AGENT_SLUG:-unknown}"
XERUS_WORKSPACE_ROOT="${XERUS_WORKSPACE_ROOT:?XERUS_WORKSPACE_ROOT must be set}"
MEMORY_ROOT="$XERUS_WORKSPACE_ROOT/.memory"

source "$(dirname "$0")/_lib.sh"
audit "SessionEnd"

# Git commit memory changes
cd "$MEMORY_ROOT" 2>/dev/null && {
  git add -A 2>/dev/null
  git diff --cached --quiet 2>/dev/null || git commit -m "session-end: $AGENT_SLUG at $(date -u +%Y-%m-%dT%H:%M:%SZ)" 2>/dev/null
}

echo "{\"event\":\"session_end\",\"agent\":\"$AGENT_SLUG\",\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}" >> "$XERUS_WORKSPACE_ROOT/shared/activity.jsonl"
