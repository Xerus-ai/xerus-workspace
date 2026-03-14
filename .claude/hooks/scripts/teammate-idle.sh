#!/bin/bash
# TeammateIdle hook: Team coordination signal
# Runs when a teammate goes idle

AGENT_SLUG="${XERUS_AGENT_SLUG:-unknown}"
XERUS_WORKSPACE_ROOT="${XERUS_WORKSPACE_ROOT:?XERUS_WORKSPACE_ROOT must be set}"

source "$(dirname "$0")/_lib.sh"
audit "TeammateIdle"

echo "{\"event\":\"teammate_idle\",\"agent\":\"$AGENT_SLUG\",\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}" >> "$XERUS_WORKSPACE_ROOT/shared/activity.jsonl"
