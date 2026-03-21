#!/usr/bin/env python3
"""Dependency cascade: when a task closes, notify unblocked downstream agents.

For each task that was blocked on the just-closed task:
1. Check if ALL its blocking dependencies are now resolved
2. If newly unblocked, write a coordination message to the agent's inbox
3. Regenerate their .task-context.md so they see READY on next wake

Usage:
    python3 cascade-unblocked.py <closer_agent_slug> <workspace_root>
"""

import sys
import os
import json
import glob
from datetime import datetime, timezone


def main():
    if len(sys.argv) < 3:
        return

    closer_slug = sys.argv[1]
    workspace_root = sys.argv[2]
    now = datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')

    # Scan all channel boards
    pattern = os.path.join(workspace_root, 'projects', '*', 'channels', '*', '.beads', 'issues.jsonl')
    issues_files = glob.glob(pattern)

    all_tasks = []
    for issues_path in issues_files:
        try:
            with open(issues_path) as f:
                for line in f:
                    line = line.strip()
                    if not line:
                        continue
                    try:
                        all_tasks.append(json.loads(line))
                    except json.JSONDecodeError:
                        continue
        except (IOError, OSError):
            continue

    if not all_tasks:
        return

    # Build task map
    task_map = {t.get('id', ''): t for t in all_tasks}

    # Scope to specific task if provided, otherwise all closed tasks by this agent
    specific_task_id = sys.argv[3] if len(sys.argv) > 3 else None

    closed_ids = set()
    if specific_task_id:
        # Only cascade for the specific just-closed task
        if specific_task_id in task_map and task_map[specific_task_id].get('status') in ('closed', 'done'):
            closed_ids.add(specific_task_id)
    else:
        # Fallback: all closed tasks by this agent (less precise but backward-compatible)
        for t in all_tasks:
            assignee = t.get('assignee', '') or ''
            if assignee == closer_slug and t.get('status') in ('closed', 'done'):
                closed_ids.add(t.get('id', ''))

    if not closed_ids:
        return

    # Find tasks that depend on any of the closed tasks
    # and check if they are now fully unblocked
    newly_unblocked = []
    for t in all_tasks:
        status = t.get('status', 'open')
        if status in ('closed', 'done'):
            continue

        deps = t.get('dependencies', [])
        block_deps = []
        for dep in deps:
            if isinstance(dep, dict) and dep.get('type') == 'blocks':
                block_deps.append(dep.get('depends_on_id', ''))
            elif isinstance(dep, str):
                block_deps.append(dep)

        if not block_deps:
            continue

        # Check if any of the closer's tasks are in this task's dependencies
        relevant = any(dep_id in closed_ids for dep_id in block_deps)
        if not relevant:
            continue

        # Check if ALL blocking deps are now resolved
        all_resolved = True
        for dep_id in block_deps:
            dep_task = task_map.get(dep_id)
            if dep_task and dep_task.get('status') not in ('closed', 'done'):
                all_resolved = False
                break

        if all_resolved:
            assignee = t.get('assignee', '') or ''
            assigned_agents = t.get('assigned_agents', []) or []
            if isinstance(assigned_agents, str):
                assigned_agents = [assigned_agents]
            all_assignees = list(set(assigned_agents + ([assignee] if assignee else [])))

            for agent in all_assignees:
                if agent and agent != closer_slug:
                    newly_unblocked.append((agent, t))

    if not newly_unblocked:
        return

    # Notify each unblocked agent
    for agent_slug, task in newly_unblocked:
        # Write coordination message to agent's inbox
        inbox_dir = os.path.join(workspace_root, 'agents', agent_slug, 'inbox')
        os.makedirs(inbox_dir, exist_ok=True)

        msg = {
            'from': closer_slug,
            'to': agent_slug,
            'type': 'dependency_unblocked',
            'content': f'Your task "{task.get("title", "")}" ({task.get("id", "")}) is now unblocked. Dependencies resolved by {closer_slug}.',
            'task_id': task.get('id', ''),
            'timestamp': now,
        }

        msg_path = os.path.join(inbox_dir, f'unblocked-{task.get("id", "unknown")}.json')
        with open(msg_path, 'w') as f:
            json.dump(msg, f, indent=2)

        # Regenerate their .task-context.md
        task_context_path = os.path.join(workspace_root, '.memory', 'agents', agent_slug, '.task-context.md')
        script_dir = os.path.dirname(os.path.abspath(__file__))
        gen_script = os.path.join(script_dir, 'generate-task-context.py')

        if os.path.exists(gen_script):
            import subprocess
            subprocess.run(
                [sys.executable, gen_script, agent_slug, workspace_root, task_context_path],
                capture_output=True, timeout=10,
            )

        print(f'Unblocked: {agent_slug} -> {task.get("id", "")} ({task.get("title", "")})')


if __name__ == '__main__':
    main()
