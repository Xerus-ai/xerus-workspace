#!/usr/bin/env python3
"""Generate .task-context.md for an agent based on beads task board.

Reads ALL channel-level .beads/issues.jsonl files to find tasks assigned
to this agent, checks dependency status, and writes a focused context file.

Usage:
    python3 generate-task-context.py <agent_slug> <workspace_root> <output_path>
"""

import sys
import os
import json
import glob
from datetime import datetime, timezone


def main():
    if len(sys.argv) < 4:
        print("Usage: generate-task-context.py <agent_slug> <workspace_root> <output_path>", file=sys.stderr)
        sys.exit(1)

    agent_slug = sys.argv[1]
    workspace_root = sys.argv[2]
    task_context_path = sys.argv[3]
    today = datetime.now(timezone.utc).strftime('%Y-%m-%d')
    now = datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')

    # Scan ALL channel-level .beads/issues.jsonl files
    # This ensures cross-channel task assignments are visible
    pattern = os.path.join(workspace_root, 'projects', '*', 'channels', '*', '.beads', 'issues.jsonl')
    issues_files = glob.glob(pattern)

    if not issues_files:
        write_status(task_context_path, agent_slug, now, 'NO TASKS',
                     'No channel-level task boards found. Read your CLAUDE.md and working.md for guidance.')
        return

    # Parse all tasks from all channels
    all_tasks = []
    for issues_path in issues_files:
        channel_dir = os.path.dirname(os.path.dirname(issues_path))  # up from .beads/issues.jsonl
        try:
            with open(issues_path) as f:
                for line in f:
                    line = line.strip()
                    if not line:
                        continue
                    try:
                        task = json.loads(line)
                        task['_channel_dir'] = channel_dir
                        all_tasks.append(task)
                    except json.JSONDecodeError:
                        continue
        except (IOError, OSError):
            continue

    if not all_tasks:
        write_status(task_context_path, agent_slug, now, 'NO TASKS',
                     'No tasks found across any channel board.')
        return

    # Build task ID -> task lookup (across all channels)
    all_task_map = {t.get('id', ''): t for t in all_tasks}

    # Filter tasks assigned to this agent (handle both 'assignee' and 'assigned_agents')
    my_tasks = []
    for t in all_tasks:
        assignee = t.get('assignee', '') or ''
        assigned_agents = t.get('assigned_agents', []) or []
        if isinstance(assigned_agents, str):
            assigned_agents = [assigned_agents]
        all_assignees = assigned_agents + ([assignee] if assignee else [])
        status = t.get('status', 'open')
        if agent_slug in all_assignees and status not in ('closed', 'done'):
            my_tasks.append(t)

    if not my_tasks:
        write_status(task_context_path, agent_slug, now, 'IDLE',
                     'No tasks assigned to you on any channel board.\nCheck your CLAUDE.md and working.md for guidance.')
        return

    # Classify tasks as READY or BLOCKED
    ready_tasks = []
    blocked_tasks = []
    for t in my_tasks:
        resolved, blockers = check_deps_resolved(t, all_task_map)
        if resolved:
            ready_tasks.append(t)
        else:
            blocked_tasks.append((t, blockers))

    # Sort ready tasks by priority (lower number = higher priority)
    ready_tasks.sort(key=lambda t: int(t.get('priority', 2)))

    # Write task context
    with open(task_context_path, 'w') as f:
        f.write(f"# Task Context -- {agent_slug}\n")
        f.write(f"Generated: {now}\n\n")

        if not ready_tasks and blocked_tasks:
            write_blocked(f, blocked_tasks)
        elif ready_tasks:
            write_ready(f, ready_tasks, blocked_tasks, all_task_map, agent_slug, today)
        else:
            f.write("## Status: IDLE\nNo actionable tasks. Check working.md for guidance.\n")


def check_deps_resolved(task, all_task_map):
    """Check if all 'blocks' type dependencies are closed/done."""
    deps = task.get('dependencies', [])
    if not deps:
        return True, []
    blocking = []
    for dep in deps:
        if isinstance(dep, dict):
            dep_type = dep.get('type', '')
            dep_id = dep.get('depends_on_id', dep.get('id', ''))
            # Only 'blocks' dependencies matter, not 'parent-child'
            if dep_type != 'blocks':
                continue
        else:
            dep_id = str(dep)
        dep_task = all_task_map.get(dep_id)
        if dep_task:
            dep_status = dep_task.get('status', 'open')
            if dep_status not in ('closed', 'done'):
                blocking.append((dep_id, dep_task.get('title', dep_id), dep_status))
    return len(blocking) == 0, blocking


def write_status(path, agent_slug, now, status, message):
    with open(path, 'w') as f:
        f.write(f"# Task Context -- {agent_slug}\n")
        f.write(f"Generated: {now}\n\n")
        f.write(f"## Status: {status}\n{message}\n")


def write_blocked(f, blocked_tasks):
    f.write("## Status: BLOCKED\n")
    f.write("All assigned tasks have unresolved dependencies.\n\n")
    for t, blockers in blocked_tasks:
        f.write(f"### {t.get('id', '???')}: {t.get('title', 'Untitled')}\n")
        f.write("Waiting on:\n")
        for bid, btitle, bstatus in blockers:
            f.write(f"- {bid}: {btitle} ({bstatus})\n")
        f.write("\n")
    f.write("## Instructions\n")
    f.write('Output "BLOCKED: waiting for dependencies" and end session.\n')


def write_ready(f, ready_tasks, blocked_tasks, all_task_map, agent_slug, today):
    current = ready_tasks[0]
    f.write("## Current Task (READY)\n")
    f.write(f"**ID**: {current.get('id', '???')}\n")
    f.write(f"**Title**: {current.get('title', 'Untitled')}\n")
    f.write(f"**Priority**: P{current.get('priority', 2)}\n")

    # Acceptance criteria
    acceptance = current.get('acceptance_criteria', '') or current.get('acceptance', '')
    if acceptance:
        f.write(f"**Acceptance**: {str(acceptance).replace('{date}', today)}\n")

    desc = current.get('description', 'No description provided.')
    f.write(f"\n### Description\n{desc}\n\n")

    # Show resolved blocking dependencies
    deps = current.get('dependencies', [])
    block_deps = [d for d in deps if isinstance(d, dict) and d.get('type') == 'blocks']
    if block_deps:
        f.write("### Dependencies (all resolved)\n")
        for dep in block_deps:
            dep_id = dep.get('depends_on_id', dep.get('id', ''))
            dep_task = all_task_map.get(dep_id)
            if dep_task:
                dep_assignee = dep_task.get('assignee', '?')
                # Show where the upstream deliverable is
                dep_acceptance = dep_task.get('acceptance_criteria', '') or ''
                loc = ''
                if 'output/' in dep_acceptance:
                    loc = f" -> {dep_acceptance.split('output/')[0]}output/{dep_acceptance.split('output/')[1].split(' ')[0]}"
                f.write(f"- {dep_id}: {dep_task.get('title', dep_id)} (CLOSED by {dep_assignee}){loc}\n")
        f.write("\n")

    # Other ready tasks
    if len(ready_tasks) > 1:
        f.write("## Other Ready Tasks\n")
        for t in ready_tasks[1:]:
            f.write(f"- {t.get('id', '???')}: {t.get('title', 'Untitled')} (P{t.get('priority', 2)})\n")
        f.write("\n")

    # Blocked tasks
    if blocked_tasks:
        f.write("## Blocked Tasks\n")
        for t, blockers in blocked_tasks:
            blocker_str = ', '.join(bid for bid, _, _ in blockers)
            f.write(f"- {t.get('id', '???')}: {t.get('title', 'Untitled')} (waiting on: {blocker_str})\n")
        f.write("\n")

    f.write("## Instructions\n")
    f.write("1. Do the Current Task above. Nothing else.\n")
    f.write(f'2. When done, close it: `bd close {current.get("id", "TASK_ID")} --reason "your summary"`\n')
    f.write(f"3. Save progress to .memory/agents/{agent_slug}/working.md\n")


if __name__ == '__main__':
    main()
