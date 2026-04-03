#!/bin/bash
# PreToolUse hook: HITL authorization, bd-close validation
# Runs before each tool execution

TOOL_NAME="${CLAUDE_TOOL_NAME:-unknown}"
AGENT_SLUG="${XERUS_AGENT_SLUG:-unknown}"
XERUS_WORKSPACE_ROOT="${XERUS_WORKSPACE_ROOT:?XERUS_WORKSPACE_ROOT must be set}"

source "$(dirname "$0")/_lib.sh"
audit "PreToolUse"

# Resolve agent paths using new channel-scoped structure
AGENT_DIR=$(resolve_agent_dir "$AGENT_SLUG")
CHANNEL_REL=$(resolve_channel_dir "$AGENT_SLUG")
CHANNEL_DIR=""
if [ -n "$CHANNEL_REL" ]; then
  CHANNEL_DIR="$XERUS_WORKSPACE_ROOT/$CHANNEL_REL"
fi

# --- HITL Check 1: Agent pause state ---
PAUSE_FILE="$AGENT_DIR/.paused"
if [ -f "$PAUSE_FILE" ]; then
  echo "Agent $AGENT_SLUG is paused. Tool $TOOL_NAME blocked."
  exit 1
fi

# --- HITL Check 2: Tool authorization required ---
HITL_RULES_FILE="$AGENT_DIR/.hitl_required"
if [ -f "$HITL_RULES_FILE" ]; then
  if grep -qxF "$TOOL_NAME" "$HITL_RULES_FILE" 2>/dev/null; then
    TOOL_USE_ID="${CLAUDE_TOOL_USE_ID:-}"
    # Validate TOOL_USE_ID format (prevent path traversal)
    if [ -n "$TOOL_USE_ID" ] && ! validate_safe_id "$TOOL_USE_ID"; then
      echo "ERROR: Invalid TOOL_USE_ID format"
      exit 1
    fi
    if [ -z "$TOOL_USE_ID" ]; then
      echo "ERROR: Tool $TOOL_NAME requires HITL but SDK provided no TOOL_USE_ID."
      exit 1
    fi
    APPROVED_FILE="$AGENT_DIR/.hitl_approved/$TOOL_USE_ID"
    if [ ! -f "$APPROVED_FILE" ]; then
      echo "Tool $TOOL_NAME requires user authorization (HITL)."
      mkdir -p "$AGENT_DIR/.hitl_pending"
      local_ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
      # Write atomically via temp file
      TMPFILE=$(mktemp "$AGENT_DIR/.hitl_pending/.tmp.XXXXXX" 2>/dev/null || echo "$AGENT_DIR/.hitl_pending/$TOOL_USE_ID.json")
      printf '{"tool":"%s","agent":"%s","tool_use_id":"%s","timestamp":"%s"}\n' \
        "$TOOL_NAME" "$AGENT_SLUG" "$TOOL_USE_ID" "$local_ts" > "$TMPFILE"
      if [ "$TMPFILE" != "$AGENT_DIR/.hitl_pending/$TOOL_USE_ID.json" ]; then
        mv "$TMPFILE" "$AGENT_DIR/.hitl_pending/$TOOL_USE_ID.json"
      fi
      exit 1
    fi
  fi
fi

# --- Check 3: bd close deliverable validation ---
# Before allowing `bd close`, verify acceptance criteria are met
if [ "$TOOL_NAME" = "Bash" ]; then
  BASH_CMD="${CLAUDE_TOOL_INPUT_command:-}"

  if echo "$BASH_CMD" | grep -qE '\bbd\s+close\s+'; then
    TASK_ID=$(echo "$BASH_CMD" | grep -oE 'bd\s+close\s+([^ ";&|]+)' | head -1 | awk '{print $3}')

    if [ -n "$TASK_ID" ] && validate_safe_id "$TASK_ID"; then
      # CHANNEL_DIR already resolved at start of hook
      if [ -n "$CHANNEL_DIR" ] && ! validate_workspace_path "$CHANNEL_DIR"; then
        echo "ERROR: Channel path escapes workspace boundary"
        exit 1
      fi

      # Get acceptance criteria from bd show
      BD_DIR="${CHANNEL_DIR:-.}"
      if [ -d "$BD_DIR/.beads" ]; then
        ACCEPTANCE=$(cd "$BD_DIR" 2>/dev/null && bd show "$TASK_ID" --json 2>/dev/null | $PYTHON -c "
import sys, json
try:
    data = json.load(sys.stdin)
    task = data[0] if isinstance(data, list) else data
    print(task.get('acceptance_criteria', '') or '')
except (json.JSONDecodeError, KeyError, TypeError, IndexError):
    pass
" 2>/dev/null || true)

        if [ -n "$ACCEPTANCE" ]; then
          # Extract deliverable path from acceptance string
          DELIVERABLE=$(echo "$ACCEPTANCE" | grep -oE 'output/[^ ]+' | head -1)
          if [ -n "$DELIVERABLE" ]; then
            TODAY=$(date +%Y-%m-%d)
            DELIVERABLE=$(echo "$DELIVERABLE" | sed "s/{date}/$TODAY/g")
            FULL_PATH="$CHANNEL_DIR/$DELIVERABLE"

            if ! validate_workspace_path "$FULL_PATH"; then
              echo "ERROR: Deliverable path escapes workspace boundary"
              exit 1
            fi

            if [ ! -f "$FULL_PATH" ]; then
              echo "BLOCKED: Cannot close task $TASK_ID. Deliverable not found: $DELIVERABLE"
              echo "Create the deliverable first, then close the task."
              exit 1
            fi

            # Check minimum size if specified
            MIN_BYTES=$(echo "$ACCEPTANCE" | grep -oE '>\s*[0-9]+\s*bytes' | grep -oE '[0-9]+' || true)
            if [ -n "$MIN_BYTES" ]; then
              ACTUAL_SIZE=$(wc -c < "$FULL_PATH" 2>/dev/null || echo 0)
              if [ "$ACTUAL_SIZE" -lt "$MIN_BYTES" ]; then
                echo "BLOCKED: Deliverable $DELIVERABLE is $ACTUAL_SIZE bytes (minimum: $MIN_BYTES)."
                exit 1
              fi
            fi
          fi
        fi
      fi
    fi
  fi
fi

# --- Check 4: Channel boundary enforcement for file writes ---
# Agents can only write to their channel's directories (scratch/, output/, .memory/)
# or shared workspace locations (shared/, data/, .memory/entities/)
if [ "$TOOL_NAME" = "Write" ] || [ "$TOOL_NAME" = "Edit" ]; then
  FILE_PATH="${CLAUDE_TOOL_INPUT_file_path:-}"

  if [ -n "$FILE_PATH" ] && [ -n "$CHANNEL_DIR" ]; then
    # Resolve the file path
    RESOLVED_PATH=$(realpath -m "$FILE_PATH" 2>/dev/null || echo "$FILE_PATH")
    RESOLVED_WS=$(realpath -m "$XERUS_WORKSPACE_ROOT" 2>/dev/null || echo "$XERUS_WORKSPACE_ROOT")
    RESOLVED_CHANNEL=$(realpath -m "$CHANNEL_DIR" 2>/dev/null || echo "$CHANNEL_DIR")

    # Must be within workspace
    if ! validate_workspace_path "$FILE_PATH"; then
      echo "ERROR: File path escapes workspace boundary"
      exit 1
    fi

    # Check if writing to another channel
    if [[ "$RESOLVED_PATH" == "$RESOLVED_WS/projects/"* ]]; then
      # Writing to projects/ - must be in own channel or cross-channel output
      if [[ "$RESOLVED_PATH" != "$RESOLVED_CHANNEL/"* ]]; then
        # Writing outside own channel
        # Allow writing to other channels' output/posts.jsonl (cross-channel coordination)
        if [[ "$RESOLVED_PATH" == */output/posts.jsonl ]]; then
          : # Allowed: cross-channel coordination messages
        else
          echo "BLOCKED: Agent $AGENT_SLUG cannot write to other channels."
          echo "Path: $FILE_PATH"
          echo "Your channel: $CHANNEL_REL"
          exit 1
        fi
      fi
    fi
  fi
fi

# Log tool usage
log_activity "tool_use" "$AGENT_SLUG"
