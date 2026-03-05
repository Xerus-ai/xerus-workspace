#!/bin/bash
# TaskCompleted hook: Update beads, notify stakeholders
# Runs when a task is marked complete

AGENT_SLUG="${XERUS_AGENT_SLUG:-unknown}"
WORKSPACE_ROOT="${WORKSPACE_ROOT:-/home/daytona}"

echo "{\"event\":\"task_completed\",\"agent\":\"$AGENT_SLUG\",\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}" >> "$WORKSPACE_ROOT/shared/activity.jsonl"
