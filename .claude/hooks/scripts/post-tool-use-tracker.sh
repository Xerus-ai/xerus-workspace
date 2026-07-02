#!/bin/bash
# PostToolUse Tracker: Record files touched during session
# Appends to .memory/agents/{slug}/.session-files for use by
# pre-compact.sh (save progress) and session-end.sh (session summary)
# Event: PostToolUse
#
# Hook input arrives as JSON on stdin, parsed by parse_hook_input in _lib.sh.
# (There are NO CLAUDE_TOOL_NAME / CLAUDE_TOOL_INPUT_* env vars.)

XERUS_WORKSPACE_ROOT="${XERUS_WORKSPACE_ROOT:?XERUS_WORKSPACE_ROOT must be set}"
AGENT_SLUG="${XERUS_AGENT_SLUG:-}"

source "$(dirname "$0")/_lib.sh"
parse_hook_input

SESSION_FILES="$XERUS_WORKSPACE_ROOT/.memory/agents/$AGENT_SLUG/.session-files"

track() {
  mkdir -p "$(dirname "$SESSION_FILES")" 2>/dev/null
  echo "$1" >> "$SESSION_FILES"
}

# Only track meaningful tools (skip Glob, Grep -- too noisy)
case "$TOOL_NAME" in
  Read)
    [ -n "$FILE_PATH" ] && track "READ $FILE_PATH"
    ;;
  Write)
    [ -n "$FILE_PATH" ] && track "WRITE $FILE_PATH"
    ;;
  Edit)
    [ -n "$FILE_PATH" ] && track "EDIT $FILE_PATH"
    ;;
  Bash)
    if printf '%s' "$BASH_CMD" | grep -qE '(^|[;&|]\s*)bd\s+' 2>/dev/null; then
      track "BASH $BASH_CMD"
    fi
    ;;
esac

exit 0
