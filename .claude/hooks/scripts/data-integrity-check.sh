#!/bin/bash
# SessionEnd data integrity check — warns about orphaned scratch files
# Non-blocking: logs warnings but never fails
WORKSPACE_ROOT="${WORKSPACE_ROOT:-/home/daytona}"
AGENT_SLUG="${XERUS_AGENT_SLUG:-unknown}"
DB_PATH="$WORKSPACE_ROOT/data/company.db"

# Skip if no DB
if [ ! -f "$DB_PATH" ] || [ ! -s "$DB_PATH" ]; then
  exit 0
fi

# Check for scratch files that might contain unprocessed data
SCRATCH_COUNT=$(find "$WORKSPACE_ROOT/scratch" -type f 2>/dev/null | wc -l)
if [ "$SCRATCH_COUNT" -gt 0 ]; then
  echo "[data-integrity] Warning: $SCRATCH_COUNT file(s) in scratch/ — consider storing valuable data in company.db or .memory/entities/ before next session"
fi

# Check for research files outside workspace (common last30days pattern)
HOME_RESEARCH=$(find ~/Documents/Last30Days -type f -newer "$DB_PATH" 2>/dev/null | wc -l)
if [ "$HOME_RESEARCH" -gt 0 ]; then
  echo "[data-integrity] Warning: $HOME_RESEARCH new research file(s) in ~/Documents/Last30Days/ not yet imported to company.db"
fi
