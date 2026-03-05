#!/bin/bash
# TeammateIdle hook: Team coordination signal
# Runs when a teammate goes idle

AGENT_SLUG="${XERUS_AGENT_SLUG:-unknown}"
WORKSPACE_ROOT="${WORKSPACE_ROOT:-/home/daytona}"

echo "{\"event\":\"teammate_idle\",\"agent\":\"$AGENT_SLUG\",\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}" >> "$WORKSPACE_ROOT/shared/activity.jsonl"
