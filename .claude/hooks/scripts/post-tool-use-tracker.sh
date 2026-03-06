#!/bin/bash
# Hook: PostToolUse - Tool Usage Tracker
# Track and log tool usage analytics for monitoring and optimization.
#
# Event: PostToolUse
# Matcher: Edit|Write

TRACKER_FILE=".claude/tool-usage.log"

# Append tool usage entry with timestamp
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
TOOL_NAME="${TOOL_NAME:-unknown}"

echo "$TIMESTAMP $TOOL_NAME" >> "$TRACKER_FILE"
