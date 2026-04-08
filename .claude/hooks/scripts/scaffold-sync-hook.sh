#!/bin/bash
# Hook: PostToolUse - Deterministic Scaffold & Sync
# Fires on Write/Edit. Detects sync-relevant file writes and performs
# side-effects that MUST happen reliably (not via agent instructions).
#
# Two patterns:
#   1. agents/{slug}/config.json → scaffold soul files, memory, index, workspace.db
#   2. projects/{domain}/channels/{channel}/CLAUDE.md → scaffold channel dirs, workspace.db
#
# Event: PostToolUse
# Matcher: Write|Edit

XERUS_WORKSPACE_ROOT="${XERUS_WORKSPACE_ROOT:?XERUS_WORKSPACE_ROOT must be set}"
TOOL_NAME="${CLAUDE_TOOL_NAME:-unknown}"
AGENT_SLUG="${XERUS_AGENT_SLUG:-unknown}"

source "$(dirname "$0")/_lib.sh"

# Only trigger on Write or Edit
case "$TOOL_NAME" in
  Write|Edit) ;;
  *) exit 0 ;;
esac

# Extract file_path from hook input
FILE_PATH=""
if command -v jq &>/dev/null; then
  HOOK_INPUT=$(cat 2>/dev/null)
  if [ -n "$HOOK_INPUT" ]; then
    FILE_PATH=$(echo "$HOOK_INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
  fi
fi
FILE_PATH="${FILE_PATH:-${CLAUDE_TOOL_FILE_PATH:-}}"

if [ -z "$FILE_PATH" ]; then
  exit 0
fi

# Normalize path: strip workspace root prefix if present
REL_PATH="${FILE_PATH#$XERUS_WORKSPACE_ROOT/}"
REL_PATH="${REL_PATH#/home/daytona/}"
REL_PATH="${REL_PATH#/home/daytona/workspace/}"

TEMPLATE_DIR="$XERUS_WORKSPACE_ROOT/.xerus/templates/agent"
DB_PATH="$XERUS_WORKSPACE_ROOT/data/workspace.db"

# Sanitize a string for safe use in sed replacement (escape | and &)
sanitize_for_sed() {
  printf '%s' "$1" | sed 's/[|&/\\]/\\&/g'
}

# Sanitize a string for safe use in SQLite single-quoted literals
sanitize_for_sql() {
  printf '%s' "$1" | sed "s/'/''/g"
}

# Validate a jq-extracted field contains only safe characters
# Allows alphanumeric, spaces, hyphens, underscores, dots
validate_field() {
  local val="$1"
  if [[ "$val" =~ ^[a-zA-Z0-9\ ._-]*$ ]]; then
    return 0
  fi
  return 1
}

# ─────────────────────────────────────────────────────────────────────
# Pattern 1: Agent created — agents/{slug}/config.json
# ─────────────────────────────────────────────────────────────────────
if [[ "$REL_PATH" =~ ^agents/([a-zA-Z0-9._-]+)/config\.json$ ]]; then
  NEW_SLUG="${BASH_REMATCH[1]}"
  AGENT_DIR="$XERUS_WORKSPACE_ROOT/agents/$NEW_SLUG"

  validate_safe_id "$NEW_SLUG" || { echo "ERROR: Unsafe agent slug: $NEW_SLUG" >&2; exit 0; }
  validate_workspace_path "$AGENT_DIR" || { echo "ERROR: Path traversal: $AGENT_DIR" >&2; exit 0; }

  audit "ScaffoldSync:agent_create:$NEW_SLUG"

  # Read agent metadata from config.json — validate every field before use
  AGENT_NAME="$NEW_SLUG"
  AGENT_ROLE="specialist"
  AGENT_MODEL="sonnet"
  AGENT_CHANNEL=""
  AGENT_PROJECT=""
  AGENT_AUTONOMY="supervised"
  if command -v jq &>/dev/null && [ -f "$AGENT_DIR/config.json" ]; then
    _name=$(jq -r '.name // empty' "$AGENT_DIR/config.json" 2>/dev/null)
    _role=$(jq -r '.role // "specialist"' "$AGENT_DIR/config.json" 2>/dev/null)
    _model=$(jq -r '.model // "sonnet"' "$AGENT_DIR/config.json" 2>/dev/null)
    _channel=$(jq -r '.primary_channel // empty' "$AGENT_DIR/config.json" 2>/dev/null)
    _project=$(jq -r '.domain // .project // empty' "$AGENT_DIR/config.json" 2>/dev/null)
    _autonomy=$(jq -r '.autonomy_level // .autonomy // "supervised"' "$AGENT_DIR/config.json" 2>/dev/null)

    validate_field "$_name" && [ -n "$_name" ] && AGENT_NAME="$_name"
    validate_field "$_role" && AGENT_ROLE="$_role"
    validate_field "$_model" && AGENT_MODEL="$_model"
    validate_field "$_channel" && AGENT_CHANNEL="$_channel"
    validate_field "$_project" && AGENT_PROJECT="$_project"
    validate_field "$_autonomy" && AGENT_AUTONOMY="$_autonomy"
  fi

  CHANNEL_PATH=""
  if [ -n "$AGENT_PROJECT" ] && [ -n "$AGENT_CHANNEL" ]; then
    CHANNEL_PATH="projects/$AGENT_PROJECT/channels/$AGENT_CHANNEL"
  fi

  SCAFFOLDED=()

  # Sanitize all values for sed substitution
  S_NAME=$(sanitize_for_sed "$AGENT_NAME")
  S_SLUG=$(sanitize_for_sed "$NEW_SLUG")
  S_ROLE=$(sanitize_for_sed "$AGENT_ROLE")
  S_MODEL=$(sanitize_for_sed "$AGENT_MODEL")
  S_CHANNEL=$(sanitize_for_sed "${AGENT_CHANNEL:-general}")
  S_CPATH=$(sanitize_for_sed "${CHANNEL_PATH:-projects/default/channels/general}")
  S_PROJECT=$(sanitize_for_sed "${AGENT_PROJECT:-default}")
  S_AUTONOMY=$(sanitize_for_sed "$AGENT_AUTONOMY")

  # Helper: create file from template with substitution
  scaffold_from_template() {
    local target="$1"
    local template="$2"
    if [ ! -f "$target" ] && [ -f "$template" ]; then
      sed \
        -e "s|{{AGENT_NAME}}|$S_NAME|g" \
        -e "s|{{AGENT_SLUG}}|$S_SLUG|g" \
        -e "s|{{AGENT_ROLE}}|$S_ROLE|g" \
        -e "s|{{MODEL}}|$S_MODEL|g" \
        -e "s|{{CHANNEL_NAME}}|$S_CHANNEL|g" \
        -e "s|{{CHANNEL_PATH}}|$S_CPATH|g" \
        -e "s|{{PROJECT_NAME}}|$S_PROJECT|g" \
        -e "s|{{AUTONOMY_LEVEL}}|$S_AUTONOMY|g" \
        -e "s|{{SKILLS_JSON}}|[]|g" \
        -e "s|{{SKILLS_LIST}}|(check .claude/skills/ for available skills)|g" \
        -e "s|{{SKILLS_TABLE}}||g" \
        -e "s|{{EXAMPLE_TASKS}}|- Ask me what I can do|g" \
        -e "s|{{KNOWLEDGE_LIST}}||g" \
        -e "s|{{ADAPTER_TYPE}}|claudecode|g" \
        -e "s|{{CREATED_AT}}|$(date -u +%Y-%m-%dT%H:%M:%SZ)|g" \
        "$template" > "$target"
      SCAFFOLDED+=("$(basename "$target")")
    fi
  }

  # Scaffold soul files from templates (idempotent — skip if exists)
  scaffold_from_template "$AGENT_DIR/SOUL.md" "$TEMPLATE_DIR/SOUL.md.tmpl"
  scaffold_from_template "$AGENT_DIR/BOOTSTRAP.md" "$TEMPLATE_DIR/BOOTSTRAP.md.tmpl"
  scaffold_from_template "$AGENT_DIR/STATUS.md" "$TEMPLATE_DIR/STATUS.md.tmpl"
  scaffold_from_template "$AGENT_DIR/USER.md" "$TEMPLATE_DIR/USER.md.tmpl"
  scaffold_from_template "$AGENT_DIR/RELATIONSHIPS.md" "$TEMPLATE_DIR/RELATIONSHIPS.md.tmpl"
  scaffold_from_template "$AGENT_DIR/HEARTBEAT.md" "$TEMPLATE_DIR/HEARTBEAT.md.tmpl"
  scaffold_from_template "$AGENT_DIR/CLAUDE.md" "$TEMPLATE_DIR/CLAUDE.md.tmpl"

  # Create memory directories
  MEMORY_DIR="$XERUS_WORKSPACE_ROOT/.memory/agents/$NEW_SLUG"
  mkdir -p "$MEMORY_DIR"
  if [ ! -f "$MEMORY_DIR/working.md" ]; then
    printf '# %s Working Context\n\n(session not started)\n' "$AGENT_NAME" > "$MEMORY_DIR/working.md"
    SCAFFOLDED+=("working.md")
  fi
  if [ ! -f "$MEMORY_DIR/expertise.md" ]; then
    printf '# %s Expertise\n\nCapabilities developed through work.\n' "$AGENT_NAME" > "$MEMORY_DIR/expertise.md"
    SCAFFOLDED+=("expertise.md")
  fi

  # Create inbox directories
  mkdir -p "$AGENT_DIR/inbox/processed" "$AGENT_DIR/knowledge"

  # Update agents/index.json with flock to prevent race conditions
  INDEX_FILE="$XERUS_WORKSPACE_ROOT/agents/index.json"
  if command -v jq &>/dev/null; then
    (
      flock -x 200 2>/dev/null || true
      if [ ! -f "$INDEX_FILE" ]; then
        echo '{"agents":{},"updated_at":""}' > "$INDEX_FILE"
      fi
      UPDATED=$(jq \
        --arg slug "$NEW_SLUG" \
        --arg name "$AGENT_NAME" \
        --arg role "$AGENT_ROLE" \
        --arg model "$AGENT_MODEL" \
        --arg domain "$AGENT_PROJECT" \
        --arg channel "$AGENT_CHANNEL" \
        --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        '.agents[$slug] = {name: $name, role: $role, model: $model, domain: $domain, primary_channel: $channel} | .updated_at = $ts' \
        "$INDEX_FILE" 2>/dev/null)
      if [ -n "$UPDATED" ]; then
        echo "$UPDATED" > "$INDEX_FILE"
      fi
    ) 200>"$INDEX_FILE.lock"
  fi

  # Register in workspace.db (idempotent — INSERT OR IGNORE)
  # All values sanitized for SQL single-quote safety
  if command -v sqlite3 &>/dev/null && [ -f "$DB_PATH" ]; then
    SQL_NAME=$(sanitize_for_sql "$AGENT_NAME")
    SQL_ROLE=$(sanitize_for_sql "$AGENT_ROLE")
    SQL_AUTONOMY=$(sanitize_for_sql "$AGENT_AUTONOMY")
    sqlite3 "$DB_PATH" \
      "INSERT OR IGNORE INTO agents (slug, name, adapter_type, role, autonomy_level, status) VALUES ('$NEW_SLUG', '$SQL_NAME', 'claudecode', '$SQL_ROLE', '$SQL_AUTONOMY', 'idle');" \
      2>/dev/null
  fi

  log_activity "agent_scaffolded" "$AGENT_SLUG"

  # Talk back — hook output is visible to the agent
  if [ ${#SCAFFOLDED[@]} -gt 0 ]; then
    echo "Agent '$NEW_SLUG' scaffolded: ${SCAFFOLDED[*]}, memory, inbox, index.json, workspace.db"
  else
    echo "Agent '$NEW_SLUG' already scaffolded (all files exist)"
  fi
  exit 0
fi

# ─────────────────────────────────────────────────────────────────────
# Pattern 2: Channel created — projects/{domain}/channels/{channel}/CLAUDE.md
# ─────────────────────────────────────────────────────────────────────
if [[ "$REL_PATH" =~ ^projects/([a-zA-Z0-9._-]+)/channels/([a-zA-Z0-9._-]+)/CLAUDE\.md$ ]]; then
  DOMAIN_SLUG="${BASH_REMATCH[1]}"
  CHANNEL_SLUG="${BASH_REMATCH[2]}"
  CHANNEL_DIR="$XERUS_WORKSPACE_ROOT/projects/$DOMAIN_SLUG/channels/$CHANNEL_SLUG"

  validate_safe_id "$DOMAIN_SLUG" || exit 0
  validate_safe_id "$CHANNEL_SLUG" || exit 0
  validate_workspace_path "$CHANNEL_DIR" || exit 0

  audit "ScaffoldSync:channel_create:$DOMAIN_SLUG/$CHANNEL_SLUG"

  # Create channel subdirectories (idempotent)
  mkdir -p "$CHANNEL_DIR/output/deliverables"
  mkdir -p "$CHANNEL_DIR/scratch"
  mkdir -p "$CHANNEL_DIR/data"
  mkdir -p "$CHANNEL_DIR/.beads"

  # Initialize posts.jsonl (idempotent)
  touch "$CHANNEL_DIR/output/posts.jsonl"

  # Initialize beads issues file (idempotent)
  touch "$CHANNEL_DIR/.beads/issues.jsonl"

  # Register domain and channel in workspace.db if not exists
  # DOMAIN_SLUG and CHANNEL_SLUG are already validated by validate_safe_id
  # (only [a-zA-Z0-9._-]) so no SQL injection risk
  FULL_CHANNEL_SLUG="${DOMAIN_SLUG}--${CHANNEL_SLUG}"
  DOMAIN_DISPLAY=$(echo "$DOMAIN_SLUG" | sed 's/-/ /g')
  CHANNEL_DISPLAY=$(echo "$CHANNEL_SLUG" | sed 's/-/ /g')
  if command -v sqlite3 &>/dev/null && [ -f "$DB_PATH" ]; then
    sqlite3 "$DB_PATH" \
      "INSERT OR IGNORE INTO domains (slug, name) VALUES ('$DOMAIN_SLUG', '$(sanitize_for_sql "$DOMAIN_DISPLAY")');" \
      2>/dev/null
    sqlite3 "$DB_PATH" \
      "INSERT OR IGNORE INTO channels (slug, name, domain_slug) VALUES ('$FULL_CHANNEL_SLUG', '$(sanitize_for_sql "$CHANNEL_DISPLAY")', '$DOMAIN_SLUG');" \
      2>/dev/null
  fi

  log_activity "channel_scaffolded" "$AGENT_SLUG"

  echo "Channel '$DOMAIN_SLUG/$CHANNEL_SLUG' initialized: output/, scratch/, data/, .beads/, posts.jsonl, workspace.db"
  exit 0
fi

# No pattern matched — nothing to do
exit 0
