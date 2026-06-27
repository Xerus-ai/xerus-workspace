#!/bin/bash
# TeammateIdle hook: Notify channel lead when teammate has no work
# The lead can reassign tasks or create ad-hoc work.

AGENT_SLUG="${XERUS_AGENT_SLUG:-unknown}"
XERUS_WORKSPACE_ROOT="${XERUS_WORKSPACE_ROOT:?XERUS_WORKSPACE_ROOT must be set}"
TEAMMATE_ID="${CLAUDE_TEAMMATE_ID:-unknown}"
TEAMMATE_NAME="${CLAUDE_TEAMMATE_NAME:-unknown}"

source "$(dirname "$0")/_lib.sh"
audit "TeammateIdle"

# Find the channel lead (first agent in the channel's team roster)
CHANNEL_REL=$(resolve_channel_dir "$AGENT_SLUG")
if [ -n "$CHANNEL_REL" ]; then
  CHANNEL_CLAUDE="$XERUS_WORKSPACE_ROOT/$CHANNEL_REL/CLAUDE.md"
  if [ -f "$CHANNEL_CLAUDE" ]; then
    # Write idle notification to posts.jsonl (hooks are infrastructure, not agent code)
    POSTS_FILE="$XERUS_WORKSPACE_ROOT/$CHANNEL_REL/output/posts.jsonl"
    mkdir -p "$(dirname "$POSTS_FILE")"
    local_ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    printf '{"agent_slug":"%s","content":"Teammate %s is idle and available for work.","message_type":"system","metadata":{"event":"teammate_idle"},"posted_at":"%s"}\n' \
      "$AGENT_SLUG" "$TEAMMATE_NAME" "$local_ts" >> "$POSTS_FILE"
  fi
fi

log_activity "teammate_idle" "$AGENT_SLUG"
