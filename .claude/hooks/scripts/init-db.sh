#!/bin/bash
# Initialize workspace databases from schemas if tables are missing
# - company.db: business data (research, prospects, competitors, etc.)
# - workspace.db: execution data (agents, sessions, heartbeats, etc.)
XERUS_WORKSPACE_ROOT="${XERUS_WORKSPACE_ROOT:?XERUS_WORKSPACE_ROOT must be set}"

# Paths for company.db (business data)
COMPANY_DB_PATH="$XERUS_WORKSPACE_ROOT/data/company.db"
COMPANY_SCHEMA_PATH="$XERUS_WORKSPACE_ROOT/data/schema.sql"

# Paths for workspace.db (execution data)
WORKSPACE_DB_PATH="$XERUS_WORKSPACE_ROOT/data/workspace.db"
WORKSPACE_SCHEMA_PATH="$XERUS_WORKSPACE_ROOT/data/workspace-schema.sql"

# Sentinel files for fast path
COMPANY_SENTINEL="$XERUS_WORKSPACE_ROOT/data/.company-db-initialized"
WORKSPACE_SENTINEL="$XERUS_WORKSPACE_ROOT/data/.workspace-db-initialized"

# Ensure data directory exists
mkdir -p "$XERUS_WORKSPACE_ROOT/data"

# Function to initialize a database
init_db() {
  local db_path="$1"
  local schema_path="$2"
  local sentinel_path="$3"
  local db_name="$4"
  local extensions_dir="$5"

  # Fast path: skip if already initialized
  if [ -f "$sentinel_path" ]; then
    return 0
  fi

  # Skip if schema doesn't exist
  if [ ! -f "$schema_path" ]; then
    return 0
  fi

  # Check for actual tables, not just file size
  local table_count=0
  if [ -f "$db_path" ] && [ -s "$db_path" ]; then
    table_count=$(sqlite3 "$db_path" "SELECT COUNT(*) FROM sqlite_master WHERE type='table';" 2>/dev/null || echo 0)
  fi

  if [ "$table_count" -eq 0 ]; then
    sqlite3 "$db_path" < "$schema_path"
    echo "Initialized $db_name from $(basename "$schema_path")"

    # Load extensions if directory provided and exists
    if [ -n "$extensions_dir" ] && [ -d "$extensions_dir" ]; then
      for ext in "$extensions_dir"/*.sql; do
        [ -f "$ext" ] && sqlite3 "$db_path" < "$ext" && echo "Loaded extension: $(basename "$ext")"
      done
    fi

    # Write sentinel to skip sqlite3 fork on subsequent sessions
    touch "$sentinel_path"
  fi
}

# Initialize company.db (business data)
init_db "$COMPANY_DB_PATH" "$COMPANY_SCHEMA_PATH" "$COMPANY_SENTINEL" "company.db" "$XERUS_WORKSPACE_ROOT/data/extensions"

# Initialize workspace.db (execution data)
init_db "$WORKSPACE_DB_PATH" "$WORKSPACE_SCHEMA_PATH" "$WORKSPACE_SENTINEL" "workspace.db" ""

# --- Schema migrations (always run, idempotent) ---
# These handle S3-restored databases that predate newer schema columns.
# ALTER TABLE ADD COLUMN is safe on SQLite — fails harmlessly if column exists.
migrate_workspace_db() {
  [ -f "$WORKSPACE_DB_PATH" ] || return 0

  # conversations.sdk_session_id (added in cli-native pivot)
  sqlite3 "$WORKSPACE_DB_PATH" "ALTER TABLE conversations ADD COLUMN sdk_session_id TEXT;" 2>/dev/null

  # schedules table (added in cli-native pivot)
  sqlite3 "$WORKSPACE_DB_PATH" "CREATE TABLE IF NOT EXISTS schedules (
    id TEXT PRIMARY KEY,
    agent_slug TEXT NOT NULL,
    name TEXT NOT NULL,
    prompt TEXT NOT NULL,
    rrule TEXT,
    adapter_type TEXT NOT NULL DEFAULT 'claudecode',
    model TEXT,
    status TEXT NOT NULL DEFAULT 'active',
    max_budget_usd REAL,
    allowed_tools TEXT,
    system_prompt TEXT,
    next_run_at INTEGER,
    last_run_at INTEGER,
    created_at INTEGER NOT NULL DEFAULT (unixepoch()),
    updated_at INTEGER NOT NULL DEFAULT (unixepoch())
  );" 2>/dev/null

  # schedule_runs table (added in cli-native pivot)
  sqlite3 "$WORKSPACE_DB_PATH" "CREATE TABLE IF NOT EXISTS schedule_runs (
    id TEXT PRIMARY KEY,
    schedule_id TEXT NOT NULL,
    session_id TEXT,
    status TEXT NOT NULL DEFAULT 'pending',
    pid INTEGER,
    output TEXT,
    result TEXT,
    error TEXT,
    cost_usd REAL,
    duration_ms INTEGER,
    num_turns INTEGER,
    started_at INTEGER,
    completed_at INTEGER,
    created_at INTEGER NOT NULL DEFAULT (unixepoch()),
    FOREIGN KEY (schedule_id) REFERENCES schedules(id) ON DELETE CASCADE
  );" 2>/dev/null
}
migrate_workspace_db
