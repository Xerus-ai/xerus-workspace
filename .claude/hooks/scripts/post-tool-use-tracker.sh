#!/bin/bash
# Hook: PostToolUse - Tool Usage Tracker
# Track and log tool usage analytics for monitoring and optimization.
#
# Event: PostToolUse
# Matcher: Edit|Write

XERUS_WORKSPACE_ROOT="${XERUS_WORKSPACE_ROOT:?XERUS_WORKSPACE_ROOT must be set}"
AGENT_SLUG="${XERUS_AGENT_SLUG:-unknown}"
TRACKER_FILE="$XERUS_WORKSPACE_ROOT/.claude/tool-usage.log"

source "$(dirname "$0")/_lib.sh"
audit "PostToolUseTracker"

# Append tool usage entry with timestamp
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
TOOL_NAME="${CLAUDE_TOOL_NAME:-unknown}"

echo "$TIMESTAMP $TOOL_NAME" >> "$TRACKER_FILE"
