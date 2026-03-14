#!/bin/bash
# Hook: PostToolUse - Tool Usage Tracker
# Track and log tool usage analytics for monitoring and optimization.
#
# Event: PostToolUse
# Matcher: Edit|Write

WORKSPACE_ROOT="${WORKSPACE_ROOT:-/home/daytona}"
AGENT_SLUG="${XERUS_AGENT_SLUG:-unknown}"
TRACKER_FILE="$WORKSPACE_ROOT/.claude/tool-usage.log"

# Audit trail for shell hook observability
mkdir -p "$WORKSPACE_ROOT/.xerus"
echo "{\"hook\":\"PostToolUseTracker\",\"agent\":\"$AGENT_SLUG\",\"ts\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"ok\":true}" >> "$WORKSPACE_ROOT/.xerus/hook-audit.jsonl"

# Append tool usage entry with timestamp
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
TOOL_NAME="${CLAUDE_TOOL_NAME:-unknown}"

echo "$TIMESTAMP $TOOL_NAME" >> "$TRACKER_FILE"
