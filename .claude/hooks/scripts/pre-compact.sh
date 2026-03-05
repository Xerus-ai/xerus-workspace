#!/bin/bash
# PreCompact hook: Persist working.md before context compaction
# Runs before SDK compacts context window

AGENT_SLUG="${XERUS_AGENT_SLUG:-unknown}"
WORKSPACE_ROOT="${WORKSPACE_ROOT:-/home/daytona}"
MEMORY_DIR="$WORKSPACE_ROOT/.memory/agents/$AGENT_SLUG"

# Ensure working.md exists and has a compaction marker
if [ -f "$MEMORY_DIR/working.md" ]; then
  echo "" >> "$MEMORY_DIR/working.md"
  echo "<!-- compaction at $(date -u +%Y-%m-%dT%H:%M:%SZ) -->" >> "$MEMORY_DIR/working.md"
fi

echo "{\"event\":\"pre_compact\",\"agent\":\"$AGENT_SLUG\",\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}" >> "$WORKSPACE_ROOT/shared/activity.jsonl"
