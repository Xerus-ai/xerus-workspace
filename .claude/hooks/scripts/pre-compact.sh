#!/bin/bash
# PreCompact hook: Persist working.md before context compaction
# Runs before SDK compacts context window

AGENT_SLUG="${XERUS_AGENT_SLUG:-unknown}"
WORKSPACE_ROOT="${WORKSPACE_ROOT:-/home/daytona}"
MEMORY_DIR="$WORKSPACE_ROOT/.memory/agents/$AGENT_SLUG"

# Audit trail for shell hook observability
mkdir -p "$WORKSPACE_ROOT/.xerus"
echo "{\"hook\":\"PreCompact\",\"agent\":\"$AGENT_SLUG\",\"ts\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"ok\":true}" >> "$WORKSPACE_ROOT/.xerus/hook-audit.jsonl"

if [ -f "$MEMORY_DIR/working.md" ]; then
  # Keep only the most recent compaction marker to prevent unbounded growth
  # Remove old markers, then append the new one
  sed -i '/^<!-- compaction at .* -->$/d' "$MEMORY_DIR/working.md" 2>/dev/null
  echo "" >> "$MEMORY_DIR/working.md"
  echo "<!-- compaction at $(date -u +%Y-%m-%dT%H:%M:%SZ) -->" >> "$MEMORY_DIR/working.md"
fi

TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
echo "{\"event\":\"pre_compact\",\"agent\":\"$AGENT_SLUG\",\"timestamp\":\"$TIMESTAMP\"}" >> "$WORKSPACE_ROOT/shared/activity.jsonl"
