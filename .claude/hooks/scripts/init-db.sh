#!/bin/bash
# Initialize company.db from schema if tables are missing
XERUS_WORKSPACE_ROOT="${XERUS_WORKSPACE_ROOT:?XERUS_WORKSPACE_ROOT must be set}"
DB_PATH="$XERUS_WORKSPACE_ROOT/data/company.db"
SCHEMA_PATH="$XERUS_WORKSPACE_ROOT/data/schema.sql"
SENTINEL="$XERUS_WORKSPACE_ROOT/data/.db-initialized"

# Fast path: skip if already initialized (sentinel check avoids sqlite3 fork)
if [ -f "$SENTINEL" ]; then
  exit 0
fi

# Skip if schema doesn't exist
if [ ! -f "$SCHEMA_PATH" ]; then
  exit 0
fi

mkdir -p "$(dirname "$DB_PATH")"

# Check for actual tables, not just file size
TABLE_COUNT=0
if [ -f "$DB_PATH" ] && [ -s "$DB_PATH" ]; then
  TABLE_COUNT=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM sqlite_master WHERE type='table';" 2>/dev/null || echo 0)
fi

if [ "$TABLE_COUNT" -eq 0 ]; then
  sqlite3 "$DB_PATH" < "$SCHEMA_PATH"
  echo "Initialized company.db from schema.sql"

  # Load domain extensions (marketing.sql, dev.sql, etc.)
  EXTENSIONS_DIR="$XERUS_WORKSPACE_ROOT/data/extensions"
  if [ -d "$EXTENSIONS_DIR" ]; then
    for ext in "$EXTENSIONS_DIR"/*.sql; do
      [ -f "$ext" ] && sqlite3 "$DB_PATH" < "$ext" && echo "Loaded extension: $(basename "$ext")"
    done
  fi

  # Write sentinel to skip sqlite3 fork on subsequent sessions
  touch "$SENTINEL"
fi
