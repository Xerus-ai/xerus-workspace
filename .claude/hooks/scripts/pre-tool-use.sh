#!/bin/bash
# PreToolUse hook: HITL authorization checks, tool_auth_required validation
# Runs before each tool execution

TOOL_NAME="${CLAUDE_TOOL_NAME:-unknown}"
AGENT_SLUG="${XERUS_AGENT_SLUG:-unknown}"
WORKSPACE_ROOT="${WORKSPACE_ROOT:-/home/daytona}"

# Log tool usage
echo "{\"event\":\"tool_use\",\"tool\":\"$TOOL_NAME\",\"agent\":\"$AGENT_SLUG\",\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}" >> "$WORKSPACE_ROOT/shared/activity.jsonl"
