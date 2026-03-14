#!/bin/bash
# SessionStart hook: Load working memory, update STATUS.md, check HEARTBEAT.md
# Runs when a new agent session begins

AGENT_SLUG="${XERUS_AGENT_SLUG:-unknown}"
WORKSPACE_ROOT="${WORKSPACE_ROOT:-/home/daytona}"

# Audit trail for shell hook observability
mkdir -p "$WORKSPACE_ROOT/.xerus"
echo "{\"hook\":\"SessionStart\",\"agent\":\"$AGENT_SLUG\",\"ts\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"ok\":true}" >> "$WORKSPACE_ROOT/.xerus/hook-audit.jsonl"

# Ensure memory directory exists for this agent
mkdir -p "$WORKSPACE_ROOT/.memory/agents/$AGENT_SLUG"

# Initialize company.db if needed
"$WORKSPACE_ROOT/.claude/hooks/scripts/init-db.sh"

# Touch working.md if it doesn't exist
if [ ! -f "$WORKSPACE_ROOT/.memory/agents/$AGENT_SLUG/working.md" ]; then
  echo "# Working Memory" > "$WORKSPACE_ROOT/.memory/agents/$AGENT_SLUG/working.md"
  echo "" >> "$WORKSPACE_ROOT/.memory/agents/$AGENT_SLUG/working.md"
  echo "No previous session state." >> "$WORKSPACE_ROOT/.memory/agents/$AGENT_SLUG/working.md"
fi

# Log session start to activity
echo "{\"event\":\"session_start\",\"agent\":\"$AGENT_SLUG\",\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}" >> "$WORKSPACE_ROOT/shared/activity.jsonl"
