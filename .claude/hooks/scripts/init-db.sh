#!/bin/bash
# Initialize company.db from schema if empty or missing
XERUS_WORKSPACE_ROOT="${XERUS_WORKSPACE_ROOT:?XERUS_WORKSPACE_ROOT must be set}"
DB_PATH="$XERUS_WORKSPACE_ROOT/data/company.db"
SCHEMA_PATH="$XERUS_WORKSPACE_ROOT/data/schema.sql"

# Skip if schema doesn't exist
if [ ! -f "$SCHEMA_PATH" ]; then
  exit 0
fi

# Initialize if DB doesn't exist or is empty (0 bytes)
if [ ! -f "$DB_PATH" ] || [ ! -s "$DB_PATH" ]; then
  mkdir -p "$(dirname "$DB_PATH")"
  sqlite3 "$DB_PATH" < "$SCHEMA_PATH"
  echo "Initialized company.db from schema.sql"

  # Load domain extensions (marketing.sql, dev.sql, etc.)
  EXTENSIONS_DIR="$XERUS_WORKSPACE_ROOT/data/extensions"
  if [ -d "$EXTENSIONS_DIR" ]; then
    for ext in "$EXTENSIONS_DIR"/*.sql; do
      [ -f "$ext" ] && sqlite3 "$DB_PATH" < "$ext" && echo "Loaded extension: $(basename "$ext")"
    done
  fi
fi
