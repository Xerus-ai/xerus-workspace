#!/bin/bash
# One-time historical cleanup for activity/audit feeds polluted with a bogus
# "unknown" (or empty) agent identity. This happened when the pre-fix backend
# heartbeat-daemon launched the CLI without injecting XERUS_AGENT_SLUG, so the
# hooks fell back to "unknown". That launch path is gone and the hooks now
# fail-fast (see _lib.sh resolve_activity_agent), so this script only needs to
# purge the historical rows that were written before the fix.
#
# Idempotent: rewrites each JSONL feed dropping entries whose agent field is
# "unknown" or empty. A second run on already-clean data is a no-op (removes 0).
# The rewrite is atomic (temp file + rename) so a crash cannot truncate a feed.
#
# activity.jsonl lives inside each user's workspace (per-sandbox), so this runs
# per-sandbox. session-start.sh invokes it once per workspace behind a marker.
#
# Usage: cleanup-activity-identity.sh [WORKSPACE_ROOT]
#   WORKSPACE_ROOT defaults to $XERUS_WORKSPACE_ROOT.

WS="${1:-${XERUS_WORKSPACE_ROOT:-}}"
if [ -z "$WS" ]; then
  echo "ERROR [cleanup-activity-identity]: workspace root not provided (arg or XERUS_WORKSPACE_ROOT)." >&2
  exit 1
fi

PYTHON="${PYTHON:-$(command -v python3 2>/dev/null || command -v python 2>/dev/null || echo python3)}"

# Rewrite a JSONL feed, dropping entries whose agent field is "unknown"/empty.
# Usage: clean_feed "<file>" "<agent_field_name>"
clean_feed() {
  local file="$1"
  local field="$2"
  [ -f "$file" ] || return 0

  local removed
  removed=$("$PYTHON" - "$file" "$field" <<'PY'
import json, os, sys, tempfile

path, field = sys.argv[1], sys.argv[2]
removed = 0
dir_name = os.path.dirname(path) or "."
fd, tmp = tempfile.mkstemp(dir=dir_name, prefix=".activity-clean-")
try:
    with os.fdopen(fd, "w", encoding="utf-8") as out, open(path, encoding="utf-8") as src:
        for line in src:
            stripped = line.strip()
            if not stripped:
                continue
            try:
                obj = json.loads(stripped)
            except Exception:
                # Preserve malformed lines verbatim; never silently drop unknown data.
                out.write(line if line.endswith("\n") else line + "\n")
                continue
            agent = obj.get(field)
            if agent is None or str(agent).strip() in ("", "unknown"):
                removed += 1
                continue
            out.write(json.dumps(obj) + "\n")
    os.replace(tmp, path)
except BaseException:
    try:
        os.unlink(tmp)
    except OSError:
        pass
    raise
print(removed)
PY
) || return 1

  echo "[cleanup-activity-identity] $file: removed $removed unknown/empty entries"
}

clean_feed "$WS/data/activity.jsonl" "agent" || exit 1
clean_feed "$WS/.xerus/hook-audit.jsonl" "agent" || exit 1

exit 0
