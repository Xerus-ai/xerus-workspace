#!/bin/bash
# PreToolUse hook: HITL authorization, bd-close validation, workspace.db write guard
# Runs before each tool execution.
#
# Hook I/O contract (Claude Code):
# - Input arrives as JSON on stdin: {tool_name, tool_input, tool_use_id, ...}
#   (There are NO CLAUDE_TOOL_NAME / CLAUDE_TOOL_INPUT_* env vars.)
# - Exit 2 BLOCKS the tool call and feeds stderr back to the model.
# - Exit 0 allows the call. Exit 1 is a non-blocking error and does NOT block.

AGENT_SLUG="${XERUS_AGENT_SLUG:-}"
XERUS_WORKSPACE_ROOT="${XERUS_WORKSPACE_ROOT:?XERUS_WORKSPACE_ROOT must be set}"

source "$(dirname "$0")/_lib.sh"
audit "PreToolUse"

# --- Parse hook input from stdin JSON (shared parser in _lib.sh) ---
# Sets TOOL_NAME, TOOL_USE_ID, BASH_CMD, FILE_PATH, QUESTION, QUESTIONS
parse_hook_input

# Resolve agent paths using new channel-scoped structure
AGENT_DIR=$(resolve_agent_dir "$AGENT_SLUG")
CHANNEL_REL=$(resolve_channel_dir "$AGENT_SLUG")
CHANNEL_DIR=""
if [ -n "$CHANNEL_REL" ]; then
  CHANNEL_DIR="$XERUS_WORKSPACE_ROOT/$CHANNEL_REL"
fi

# --- AskUserQuestion HITL Bridge (opt-in via flag file) ---
# Claude Code's built-in AskUserQuestion auto-resolves in headless mode.
# Intercept it here: emit the question as an hitl_request event, then
# block until the user responds via the frontend guidance UI.
# GATED: the bridge blocks until the backend writes a response file, and the
# backend side of that flow is not implemented yet. Without the gate every
# AskUserQuestion call would hang for the full timeout. Enable by creating
# .xerus/hitl-bridge-enabled once the backend responder ships.
if [ "$TOOL_NAME" = "AskUserQuestion" ] && [ -f "$XERUS_WORKSPACE_ROOT/.xerus/hitl-bridge-enabled" ]; then
  TOOL_USE_ID="${TOOL_USE_ID:-auq-$(date +%s)}"
  HITL_DIR="/tmp/xerus-hitl"
  mkdir -p "$HITL_DIR"
  PENDING_FILE="$HITL_DIR/${TOOL_USE_ID}.pending"
  RESPONSE_FILE="$HITL_DIR/${TOOL_USE_ID}.response"

  # Write pending file with question data for the backend to read
  printf '{"tool_use_id":"%s","agent_slug":"%s","questions":%s,"question":"%s","timestamp":"%s"}\n' \
    "$TOOL_USE_ID" "$AGENT_SLUG" \
    "${QUESTIONS:-null}" \
    "$(echo "$QUESTION" | sed 's/"/\\"/g')" \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$PENDING_FILE"

  # Emit hitl_request event to stderr (runner's log stream captures stderr)
  printf '{"event":"hitl_request","tool_name":"AskUserQuestion","tool_use_id":"%s","agent_slug":"%s","scenario":"ask_user","question":"%s","pause_id":"%s"}\n' \
    "$TOOL_USE_ID" "$AGENT_SLUG" \
    "$(echo "$QUESTION" | head -c 200 | sed 's/"/\\"/g')" \
    "$TOOL_USE_ID" >&2

  # Block until user responds or timeout (5 minutes)
  TIMEOUT=300
  ELAPSED=0
  while [ ! -f "$RESPONSE_FILE" ] && [ "$ELAPSED" -lt "$TIMEOUT" ]; do
    sleep 1
    ELAPSED=$((ELAPSED + 1))
  done

  if [ -f "$RESPONSE_FILE" ]; then
    # User responded — allow the tool to proceed
    # The response content is passed back but AskUserQuestion will still
    # auto-execute; the key is we gave the user time to see the question
    rm -f "$PENDING_FILE" "$RESPONSE_FILE"
    exit 0
  else
    # Timeout — deny the tool to prevent the agent from continuing without input
    rm -f "$PENDING_FILE"
    echo "AskUserQuestion timed out waiting for user response." >&2
    exit 2
  fi
fi

# --- HITL Check 1: Agent pause state ---
PAUSE_FILE="$AGENT_DIR/.paused"
if [ -f "$PAUSE_FILE" ]; then
  echo "Agent $AGENT_SLUG is paused. Tool $TOOL_NAME blocked." >&2
  exit 2
fi

# --- HITL Check 2: Tool authorization required ---
HITL_RULES_FILE="$AGENT_DIR/.hitl_required"
if [ -f "$HITL_RULES_FILE" ]; then
  if grep -qxF "$TOOL_NAME" "$HITL_RULES_FILE" 2>/dev/null; then
    # Validate TOOL_USE_ID format (prevent path traversal)
    if [ -n "$TOOL_USE_ID" ] && ! validate_safe_id "$TOOL_USE_ID"; then
      echo "ERROR: Invalid TOOL_USE_ID format" >&2
      exit 2
    fi
    if [ -z "$TOOL_USE_ID" ]; then
      echo "ERROR: Tool $TOOL_NAME requires HITL but no TOOL_USE_ID was provided." >&2
      exit 2
    fi
    APPROVED_FILE="$AGENT_DIR/.hitl_approved/$TOOL_USE_ID"
    if [ ! -f "$APPROVED_FILE" ]; then
      mkdir -p "$AGENT_DIR/.hitl_pending"
      local_ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
      # Write atomically via temp file
      TMPFILE=$(mktemp "$AGENT_DIR/.hitl_pending/.tmp.XXXXXX" 2>/dev/null || echo "$AGENT_DIR/.hitl_pending/$TOOL_USE_ID.json")
      printf '{"tool":"%s","agent":"%s","tool_use_id":"%s","timestamp":"%s"}\n' \
        "$TOOL_NAME" "$AGENT_SLUG" "$TOOL_USE_ID" "$local_ts" > "$TMPFILE"
      if [ "$TMPFILE" != "$AGENT_DIR/.hitl_pending/$TOOL_USE_ID.json" ]; then
        mv "$TMPFILE" "$AGENT_DIR/.hitl_pending/$TOOL_USE_ID.json"
      fi
      echo "Tool $TOOL_NAME requires user authorization (HITL)." >&2
      exit 2
    fi
  fi
fi

# --- Bash command checks ---
if [ "$TOOL_NAME" = "Bash" ]; then

  # --- Check 3: workspace.db write protection ---
  # workspace.db is platform-owned operational state (tasks, channels, inbox).
  # Direct SQL writes bypass channel_slug normalization, comment metadata,
  # activity logging, and SSE — mutations MUST go through mcp__platform__*
  # tools. Read-only access (SELECT) remains allowed.
  if printf '%s' "$BASH_CMD" | grep -q 'workspace\.db' \
     && printf '%s' "$BASH_CMD" | grep -qiE '\b(INSERT|UPDATE|DELETE|REPLACE|DROP|ALTER|CREATE)\b'; then
    {
      echo "BLOCKED: Direct writes to workspace.db are not allowed."
      echo "workspace.db is platform-owned operational state (tasks, channels, inbox)."
      echo "Use MCP platform tools instead:"
      echo "  create task    -> mcp__platform__create_task"
      echo "  update task    -> mcp__platform__update_task (status, comment, attachments)"
      echo "  create channel -> mcp__platform__create_channel"
      echo "  notify user    -> mcp__platform__send_notification"
      echo "Read-only SELECT queries on workspace.db remain allowed."
    } >&2
    exit 2
  fi

  # --- Check 4: bd close deliverable validation ---
  # Before allowing `bd close`, verify acceptance criteria are met
  if echo "$BASH_CMD" | grep -qE '\bbd\s+close\s+'; then
    TASK_ID=$(echo "$BASH_CMD" | grep -oE 'bd\s+close\s+([^ ";&|]+)' | head -1 | awk '{print $3}')

    if [ -n "$TASK_ID" ] && validate_safe_id "$TASK_ID"; then
      # CHANNEL_DIR already resolved at start of hook
      if [ -n "$CHANNEL_DIR" ] && ! validate_workspace_path "$CHANNEL_DIR"; then
        echo "ERROR: Channel path escapes workspace boundary" >&2
        exit 2
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
              echo "ERROR: Deliverable path escapes workspace boundary" >&2
              exit 2
            fi

            if [ ! -f "$FULL_PATH" ]; then
              {
                echo "BLOCKED: Cannot close task $TASK_ID. Deliverable not found: $DELIVERABLE"
                echo "Create the deliverable first, then close the task."
              } >&2
              exit 2
            fi

            # Check minimum size if specified
            MIN_BYTES=$(echo "$ACCEPTANCE" | grep -oE '>\s*[0-9]+\s*bytes' | grep -oE '[0-9]+' || true)
            if [ -n "$MIN_BYTES" ]; then
              ACTUAL_SIZE=$(wc -c < "$FULL_PATH" 2>/dev/null || echo 0)
              if [ "$ACTUAL_SIZE" -lt "$MIN_BYTES" ]; then
                echo "BLOCKED: Deliverable $DELIVERABLE is $ACTUAL_SIZE bytes (minimum: $MIN_BYTES)." >&2
                exit 2
              fi
            fi
          fi
        fi
      fi
    fi
  fi
fi

# --- Check 5: Channel boundary enforcement for file writes ---
# Agents can only write to their channel's directories (scratch/, output/, .memory/)
# or workspace locations (drive/, data/, .memory/entities/)
if [ "$TOOL_NAME" = "Write" ] || [ "$TOOL_NAME" = "Edit" ]; then
  if [ -n "$FILE_PATH" ] && [ -n "$CHANNEL_DIR" ]; then
    # Resolve the file path
    RESOLVED_PATH=$(realpath -m "$FILE_PATH" 2>/dev/null || echo "$FILE_PATH")
    RESOLVED_WS=$(realpath -m "$XERUS_WORKSPACE_ROOT" 2>/dev/null || echo "$XERUS_WORKSPACE_ROOT")
    RESOLVED_CHANNEL=$(realpath -m "$CHANNEL_DIR" 2>/dev/null || echo "$CHANNEL_DIR")

    # Must be within workspace
    if ! validate_workspace_path "$FILE_PATH"; then
      echo "ERROR: File path escapes workspace boundary" >&2
      exit 2
    fi

    # Check if writing to another channel
    if [[ "$RESOLVED_PATH" == "$RESOLVED_WS/projects/"* ]]; then
      # Writing to projects/ - must be in own channel or cross-channel output
      if [[ "$RESOLVED_PATH" != "$RESOLVED_CHANNEL/"* ]]; then
        # Writing outside own channel — blocked. Use MCP tools for cross-channel communication.
        {
          echo "BLOCKED: Agent $AGENT_SLUG cannot write to other channels."
          echo "Path: $FILE_PATH"
          echo "Your channel: $CHANNEL_REL"
          echo "Use mcp__platform__send_notification for cross-channel communication."
        } >&2
        exit 2
      fi
    fi
  fi
fi

# Log tool usage
log_activity "tool_use" "$AGENT_SLUG"
