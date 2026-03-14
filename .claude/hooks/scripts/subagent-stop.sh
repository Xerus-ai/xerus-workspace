#!/bin/bash
# SubagentStop hook: Subagent cleanup, merge results
# Runs when a spawned subagent finishes

AGENT_SLUG="${XERUS_AGENT_SLUG:-unknown}"
XERUS_WORKSPACE_ROOT="${XERUS_WORKSPACE_ROOT:?XERUS_WORKSPACE_ROOT must be set}"

source "$(dirname "$0")/_lib.sh"
audit "SubagentStop"

echo "{\"event\":\"subagent_stop\",\"agent\":\"$AGENT_SLUG\",\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}" >> "$XERUS_WORKSPACE_ROOT/shared/activity.jsonl"
