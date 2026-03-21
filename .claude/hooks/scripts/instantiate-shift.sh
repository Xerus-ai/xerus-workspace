#!/bin/bash
# Instantiate daily shift tasks from a channel's shift.yaml template.
# Creates a beads epic + child tasks with dependencies in the channel's .beads/.
#
# Usage:
#   bash .claude/hooks/scripts/instantiate-shift.sh projects/{domain}/channels/{channel}
#
# Idempotent: checks for existing epic with today's date label before creating.
# Requires: python3/python (for YAML parsing), bd CLI

set -euo pipefail

XERUS_WORKSPACE_ROOT="${XERUS_WORKSPACE_ROOT:?XERUS_WORKSPACE_ROOT must be set}"
source "$(dirname "$0")/_lib.sh"

CHANNEL_REL="${1:?Usage: instantiate-shift.sh projects/DOMAIN/channels/CHANNEL}"
CHANNEL_DIR="$XERUS_WORKSPACE_ROOT/$CHANNEL_REL"
SHIFT_FILE="$CHANNEL_DIR/shift.yaml"
TODAY=$(date +%Y-%m-%d)
SHIFT_LABEL="shift-$TODAY"

# Validate inputs
if [ ! -f "$SHIFT_FILE" ]; then
  echo "No shift.yaml found at $SHIFT_FILE -- skipping."
  exit 0
fi

if ! command -v bd &>/dev/null; then
  echo "ERROR: bd CLI not found. Install beads first."
  exit 1
fi

# Ensure channel has .beads/ initialized
if [ ! -d "$CHANNEL_DIR/.beads" ]; then
  (cd "$CHANNEL_DIR" && bd init --quiet 2>/dev/null || true)
fi

# Idempotency check: see if today's shift epic already exists
cd "$CHANNEL_DIR"
# Use --no-daemon to avoid timeout warnings contaminating stdout.
EXISTING=$(bd list --no-daemon --status open 2>/dev/null | grep -c "$SHIFT_LABEL" || true)
EXISTING=$(echo "$EXISTING" | tr -d '[:space:]')

# Validate the count is a number before comparing
if [ -z "$EXISTING" ] || ! [[ "$EXISTING" =~ ^[0-9]+$ ]]; then
  EXISTING=0
fi

if [ "$EXISTING" -gt 0 ]; then
  echo "Shift for $TODAY already exists ($EXISTING tasks). Skipping."
  exit 0
fi

# Parse shift.yaml and create tasks
$PYTHON - "$SHIFT_FILE" "$CHANNEL_DIR" "$TODAY" "$SHIFT_LABEL" <<'PYEOF'
import sys, os, subprocess, json, re

shift_file = sys.argv[1]
channel_dir = sys.argv[2]
today = sys.argv[3]
shift_label = sys.argv[4]

try:
    import yaml
except ImportError:
    print("ERROR: pyyaml required. Run: pip install pyyaml")
    sys.exit(1)

with open(shift_file) as f:
    shift = yaml.safe_load(f)

shift_name = shift.get('name', 'Daily Shift')
tasks = shift.get('tasks', [])

if not tasks:
    print("No tasks defined in shift.yaml")
    sys.exit(0)

def run_bd(args):
    """Run bd command in channel directory and return stdout."""
    result = subprocess.run(
        ['bd'] + args,
        cwd=channel_dir,
        capture_output=True, text=True, timeout=30
    )
    if result.returncode != 0:
        print(f"bd error: {result.stderr.strip()}")
        return None
    return result.stdout.strip()

# Step 1: Create the epic
epic_title = f"{shift_name} -- {today}"
epic_id = run_bd([
    'create', epic_title,
    '-t', 'epic',
    '-p', '1',
    '-l', shift_label,
    '--silent'
])

if not epic_id:
    print("Failed to create epic")
    sys.exit(1)

print(f"Created epic: {epic_id} -- {epic_title}")

# Step 2: Create child tasks
# Map template task IDs to beads task IDs for dependency resolution
id_map = {}

for task_def in tasks:
    template_id = task_def.get('id', '')
    title = task_def.get('title', 'Untitled')
    assignee = task_def.get('assignee', '')
    priority = str(task_def.get('priority', 2))

    # Substitute {date} in title
    title = title.replace('{date}', today)

    # Build bd create command
    bd_args = ['create', title, '--parent', epic_id, '-p', priority, '-l', shift_label, '--silent', '--force']

    if assignee:
        bd_args.extend(['-a', assignee])

    # Description from template
    desc = task_def.get('description', '')
    skills = task_def.get('skills', [])
    if skills:
        desc = f"{desc}\nSkills: {', '.join(skills)}" if desc else f"Skills: {', '.join(skills)}"
    if desc:
        bd_args.extend(['-d', desc])

    # Store acceptance in the --acceptance flag if supported
    acceptance = task_def.get('acceptance', {})
    if acceptance and isinstance(acceptance, dict):
        deliverable = acceptance.get('deliverable', '').replace('{date}', today)
        min_bytes = acceptance.get('min_bytes', '')
        acc_text = f"{deliverable} exists"
        if min_bytes:
            acc_text += f" and > {min_bytes} bytes"
        bd_args.extend(['--acceptance', acc_text])

    task_id = run_bd(bd_args)
    if task_id:
        id_map[template_id] = task_id
        print(f"  Created: {task_id} -- {title} (@{assignee})")
    else:
        print(f"  FAILED: {title}")

# Step 3: Set dependencies
for task_def in tasks:
    template_id = task_def.get('id', '')
    depends_on = task_def.get('depends_on', [])
    if not depends_on or template_id not in id_map:
        continue

    child_id = id_map[template_id]
    for dep_template_id in depends_on:
        parent_id = id_map.get(dep_template_id)
        if parent_id:
            result = run_bd(['dep', 'add', child_id, parent_id])
            if result is not None:
                print(f"  Dep: {child_id} blocked by {parent_id}")
            else:
                print(f"  FAILED dep: {child_id} -> {parent_id}")

print(f"\nShift instantiated: {len(id_map)} tasks created for {today}")
PYEOF
