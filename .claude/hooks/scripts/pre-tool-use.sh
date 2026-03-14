#!/bin/bash
# PreToolUse hook: HITL authorization checks, tool_auth_required validation
# Runs before each tool execution

TOOL_NAME="${CLAUDE_TOOL_NAME:-unknown}"
AGENT_SLUG="${XERUS_AGENT_SLUG:-unknown}"
XERUS_WORKSPACE_ROOT="${XERUS_WORKSPACE_ROOT:?XERUS_WORKSPACE_ROOT must be set}"

source "$(dirname "$0")/_lib.sh"
audit "PreToolUse"

# --- HITL Check 1: Agent pause state ---
PAUSE_FILE="$XERUS_WORKSPACE_ROOT/agents/$AGENT_SLUG/.paused"
if [ -f "$PAUSE_FILE" ]; then
  echo "Agent $AGENT_SLUG is paused. Tool $TOOL_NAME blocked. Resume via platform.resume_execution."
  exit 1
fi

# --- HITL Check 2: Tool authorization required ---
# Tools listed in .hitl_required need explicit user approval before execution.
# The backend writes approved tool IDs to .hitl_approved/{tool_use_id}
HITL_RULES_FILE="$XERUS_WORKSPACE_ROOT/agents/$AGENT_SLUG/.hitl_required"
if [ -f "$HITL_RULES_FILE" ]; then
  if grep -qxF "$TOOL_NAME" "$HITL_RULES_FILE" 2>/dev/null; then
    TOOL_USE_ID="${CLAUDE_TOOL_USE_ID:-}"
    APPROVED_FILE="$XERUS_WORKSPACE_ROOT/agents/$AGENT_SLUG/.hitl_approved/$TOOL_USE_ID"
    if [ -z "$TOOL_USE_ID" ] || [ ! -f "$APPROVED_FILE" ]; then
      echo "Tool $TOOL_NAME requires user authorization (HITL). Requesting approval."
      # Write pending approval request for backend to pick up via SSE
      mkdir -p "$XERUS_WORKSPACE_ROOT/agents/$AGENT_SLUG/.hitl_pending"
      TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
      echo "{\"tool\":\"$TOOL_NAME\",\"agent\":\"$AGENT_SLUG\",\"tool_use_id\":\"$TOOL_USE_ID\",\"timestamp\":\"$TIMESTAMP\"}" \
        > "$XERUS_WORKSPACE_ROOT/agents/$AGENT_SLUG/.hitl_pending/$TOOL_USE_ID.json"
      exit 1
    fi
  fi
fi

# Log tool usage
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
echo "{\"event\":\"tool_use\",\"tool\":\"$TOOL_NAME\",\"agent\":\"$AGENT_SLUG\",\"timestamp\":\"$TIMESTAMP\"}" >> "$XERUS_WORKSPACE_ROOT/shared/activity.jsonl"
