#!/bin/bash
# SessionStart hook: Load working memory, update STATUS.md, check HEARTBEAT.md
# Runs when a new agent session begins

AGENT_SLUG="${XERUS_AGENT_SLUG:-unknown}"
XERUS_WORKSPACE_ROOT="${XERUS_WORKSPACE_ROOT:?XERUS_WORKSPACE_ROOT must be set}"

source "$(dirname "$0")/_lib.sh"
audit "SessionStart"

# Ensure memory directory exists for this agent
mkdir -p "$XERUS_WORKSPACE_ROOT/.memory/agents/$AGENT_SLUG"

# Initialize company.db if needed
"$XERUS_WORKSPACE_ROOT/.claude/hooks/scripts/init-db.sh"

# Touch working.md if it doesn't exist
if [ ! -f "$XERUS_WORKSPACE_ROOT/.memory/agents/$AGENT_SLUG/working.md" ]; then
  echo "# Working Memory" > "$XERUS_WORKSPACE_ROOT/.memory/agents/$AGENT_SLUG/working.md"
  echo "" >> "$XERUS_WORKSPACE_ROOT/.memory/agents/$AGENT_SLUG/working.md"
  echo "No previous session state." >> "$XERUS_WORKSPACE_ROOT/.memory/agents/$AGENT_SLUG/working.md"
fi

# Log session start to activity
echo "{\"event\":\"session_start\",\"agent\":\"$AGENT_SLUG\",\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}" >> "$XERUS_WORKSPACE_ROOT/shared/activity.jsonl"
