#!/bin/bash
# PreCompact hook: Save full progress before context compaction
# The agent loses most conversation context after compaction.
# working.md is on disk -- it survives. The agent re-reads it to resume.

AGENT_SLUG="${XERUS_AGENT_SLUG:-unknown}"
XERUS_WORKSPACE_ROOT="${XERUS_WORKSPACE_ROOT:?XERUS_WORKSPACE_ROOT must be set}"

source "$(dirname "$0")/_lib.sh"
audit "PreCompact"

# Save structured progress to working.md (task, files touched, resume instructions)
SCRIPT_DIR="$(dirname "$0")"
$PYTHON "$SCRIPT_DIR/save-progress.py" "$AGENT_SLUG" "$XERUS_WORKSPACE_ROOT" 2>&1 || true

log_activity "pre_compact" "$AGENT_SLUG"
