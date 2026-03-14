#!/bin/bash
# TaskCompleted hook: Update beads, notify stakeholders
# Runs when a task is marked complete

AGENT_SLUG="${XERUS_AGENT_SLUG:-unknown}"
XERUS_WORKSPACE_ROOT="${XERUS_WORKSPACE_ROOT:?XERUS_WORKSPACE_ROOT must be set}"

source "$(dirname "$0")/_lib.sh"
audit "TaskCompleted"

echo "{\"event\":\"task_completed\",\"agent\":\"$AGENT_SLUG\",\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}" >> "$XERUS_WORKSPACE_ROOT/shared/activity.jsonl"
