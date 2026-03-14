#!/bin/bash
# Shared utilities for Xerus shell hooks

# Ensure audit directory exists (idempotent)
mkdir -p "$XERUS_WORKSPACE_ROOT/.xerus" 2>/dev/null

# Emit a structured audit trail entry to hook-audit.jsonl
# Usage: audit "HookName"
audit() {
    echo "{\"hook\":\"$1\",\"agent\":\"${XERUS_AGENT_SLUG:-unknown}\",\"ts\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"ok\":true}" >> "$XERUS_WORKSPACE_ROOT/.xerus/hook-audit.jsonl"
}
