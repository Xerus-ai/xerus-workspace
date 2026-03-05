#!/bin/bash
# SubagentStop hook: Subagent cleanup, merge results
# Runs when a spawned subagent finishes

AGENT_SLUG="${XERUS_AGENT_SLUG:-unknown}"
WORKSPACE_ROOT="${WORKSPACE_ROOT:-/home/daytona}"

echo "{\"event\":\"subagent_stop\",\"agent\":\"$AGENT_SLUG\",\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}" >> "$WORKSPACE_ROOT/shared/activity.jsonl"
