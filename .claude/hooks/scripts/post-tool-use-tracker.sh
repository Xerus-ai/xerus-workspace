#!/bin/bash
# PostToolUse Tracker: Record files touched during session
# Appends to .memory/agents/{slug}/.session-files for use by
# pre-compact.sh (save progress) and session-end.sh (session summary)
# Event: PostToolUse

XERUS_WORKSPACE_ROOT="${XERUS_WORKSPACE_ROOT:?XERUS_WORKSPACE_ROOT must be set}"
AGENT_SLUG="${XERUS_AGENT_SLUG:-unknown}"

source "$(dirname "$0")/_lib.sh"

TOOL_NAME="${CLAUDE_TOOL_NAME:-unknown}"
SESSION_FILES="$XERUS_WORKSPACE_ROOT/.memory/agents/$AGENT_SLUG/.session-files"

# Only track meaningful tools (skip Glob, Grep -- too noisy)
case "$TOOL_NAME" in
  Read)
    FILE_PATH="${CLAUDE_TOOL_INPUT_file_path:-}"
    [ -n "$FILE_PATH" ] && echo "READ $FILE_PATH" >> "$SESSION_FILES"
    ;;
  Write)
    FILE_PATH="${CLAUDE_TOOL_INPUT_file_path:-}"
    [ -n "$FILE_PATH" ] && echo "WRITE $FILE_PATH" >> "$SESSION_FILES"
    ;;
  Edit)
    FILE_PATH="${CLAUDE_TOOL_INPUT_file_path:-}"
    [ -n "$FILE_PATH" ] && echo "EDIT $FILE_PATH" >> "$SESSION_FILES"
    ;;
  Bash)
    CMD="${CLAUDE_TOOL_INPUT_command:-}"
    if echo "$CMD" | grep -qE '(^|[;&|]\s*)bd\s+' 2>/dev/null; then
      echo "BASH $CMD" >> "$SESSION_FILES"
    fi
    ;;
esac
