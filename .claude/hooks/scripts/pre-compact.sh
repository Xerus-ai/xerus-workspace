#!/bin/bash
# PreCompact hook: Persist working.md before context compaction
# Runs before SDK compacts context window

AGENT_SLUG="${XERUS_AGENT_SLUG:-unknown}"
XERUS_WORKSPACE_ROOT="${XERUS_WORKSPACE_ROOT:?XERUS_WORKSPACE_ROOT must be set}"
MEMORY_DIR="$XERUS_WORKSPACE_ROOT/.memory/agents/$AGENT_SLUG"

source "$(dirname "$0")/_lib.sh"
audit "PreCompact"

if [ -f "$MEMORY_DIR/working.md" ]; then
  # Keep only the most recent compaction marker to prevent unbounded growth
  # Remove old markers, then append the new one
  sed -i '/^<!-- compaction at .* -->$/d' "$MEMORY_DIR/working.md" 2>/dev/null
  echo "" >> "$MEMORY_DIR/working.md"
  echo "<!-- compaction at $(date -u +%Y-%m-%dT%H:%M:%SZ) -->" >> "$MEMORY_DIR/working.md"
fi

TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
echo "{\"event\":\"pre_compact\",\"agent\":\"$AGENT_SLUG\",\"timestamp\":\"$TIMESTAMP\"}" >> "$XERUS_WORKSPACE_ROOT/shared/activity.jsonl"
