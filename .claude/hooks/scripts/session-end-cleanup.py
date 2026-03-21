#!/usr/bin/env python3
"""Session end cleanup: summary, housekeeping, dashboard data.

1. Write session summary to working.md
2. Update expertise.md if patterns detected
3. Clean session temp files
4. Write dashboard data for frontend
5. Rotate activity.jsonl if oversized

Usage:
    python3 session-end-cleanup.py <agent_slug> <workspace_root>
"""

import sys
import os
import json
import glob
import shutil
from datetime import datetime, timezone


def main():
    if len(sys.argv) < 3:
        return

    agent_slug = sys.argv[1]
    workspace_root = sys.argv[2]
    now = datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
    today = datetime.now(timezone.utc).strftime('%Y-%m-%d')

    memory_dir = os.path.join(workspace_root, '.memory', 'agents', agent_slug)
    agent_dir = os.path.join(workspace_root, 'agents', agent_slug)

    # ── 1. Write session summary to working.md ──
    write_session_summary(agent_slug, workspace_root, memory_dir, now)

    # ── 2. Update expertise.md with learned patterns ──
    update_expertise(agent_slug, memory_dir)

    # ── 3. Clean session temp files ──
    clean_session_files(memory_dir, agent_dir)

    # ── 4. Write dashboard data ──
    write_dashboard_data(agent_slug, workspace_root, today, now)

    # ── 5. Rotate activity.jsonl if oversized ──
    try:
        rotate_activity_log(workspace_root, today)
    except (IOError, OSError):
        pass  # File may be locked by concurrent agent

    # ── 6. Clean old scratch files ──
    clean_scratch(workspace_root)


def write_session_summary(agent_slug, workspace_root, memory_dir, now):
    """Write final session summary to working.md."""
    working_path = os.path.join(memory_dir, 'working.md')
    task_context_path = os.path.join(memory_dir, '.task-context.md')
    session_files_path = os.path.join(memory_dir, '.session-files')

    # Read task info
    task_id = ''
    task_title = ''
    task_status = 'unknown'
    if os.path.exists(task_context_path):
        with open(task_context_path, encoding='utf-8', errors='ignore') as f:
            for line in f:
                if line.startswith('**ID**:'):
                    task_id = line.replace('**ID**:', '').strip()
                if line.startswith('**Title**:'):
                    task_title = line.replace('**Title**:', '').strip()
                if '## Status: BLOCKED' in line:
                    task_status = 'blocked'
                if '## Status: IDLE' in line:
                    task_status = 'idle'

    # Check if task was closed (look in session-files for bd close)
    closed = False
    if os.path.exists(session_files_path):
        with open(session_files_path, encoding='utf-8', errors='ignore') as f:
            for line in f:
                if 'bd close' in line or 'bd close' in line.lower():
                    closed = True
                    task_status = 'closed'

    # Read files touched
    files_written = []
    files_read = []
    if os.path.exists(session_files_path):
        with open(session_files_path, encoding='utf-8', errors='ignore') as f:
            for line in f:
                line = line.strip()
                if line.startswith('WRITE ') or line.startswith('EDIT '):
                    files_written.append(line.split(' ', 1)[1])
                elif line.startswith('READ '):
                    files_read.append(line.split(' ', 1)[1])

    # Preserve previous session history
    prev_history = ''
    if os.path.exists(working_path):
        with open(working_path, encoding='utf-8', errors='ignore') as f:
            content = f.read()
        # Keep "## Previous Sessions" section if it exists
        if '## Previous Sessions' in content:
            idx = content.index('## Previous Sessions')
            prev_history = content[idx:]

    # Write new working.md
    with open(working_path, 'w') as f:
        f.write(f"# Working Memory -- {agent_slug}\n\n")
        f.write(f"## Last Session ({now})\n")
        if task_id:
            f.write(f"Task: {task_id} \"{task_title}\" -> {task_status.upper()}\n")
        else:
            f.write(f"Self-directed work (no task assigned)\n")

        if files_written:
            f.write(f"\nDeliverables:\n")
            seen = set()
            for fw in files_written:
                if fw not in seen:
                    seen.add(fw)
                    f.write(f"- {fw}\n")

        f.write(f"\n## Active Tasks\n")
        f.write(f"Check .task-context.md on next wake for current assignments.\n")

        if prev_history:
            f.write(f"\n{prev_history}")
        f.write("\n")


def update_expertise(agent_slug, memory_dir):
    """Append learned patterns to expertise.md if session produced insights."""
    expertise_path = os.path.join(memory_dir, 'expertise.md')
    session_files_path = os.path.join(memory_dir, '.session-files')

    if not os.path.exists(session_files_path):
        return

    # Count skill usage to detect patterns
    with open(session_files_path, encoding='utf-8', errors='ignore') as f:
        lines = f.readlines()

    skills_used = set()
    for line in lines:
        if '.claude/skills/' in line:
            # Extract skill name from path
            parts = line.split('.claude/skills/')
            if len(parts) > 1:
                skill_name = parts[1].split('/')[0]
                skills_used.add(skill_name)

    if not skills_used:
        return

    # Append skill usage to expertise (agent builds this over time)
    existing = ''
    if os.path.exists(expertise_path):
        with open(expertise_path, encoding='utf-8', errors='ignore') as f:
            existing = f.read()

    # Only append if these skills aren't already mentioned
    new_skills = [s for s in skills_used if s not in existing]
    if new_skills:
        with open(expertise_path, 'a') as f:
            if not existing.strip():
                f.write(f"# Expertise -- {agent_slug}\n\n## Skills Used\n")
            f.write(f"- {', '.join(new_skills)} (session {datetime.now(timezone.utc).strftime('%Y-%m-%d')})\n")


def clean_session_files(memory_dir, agent_dir):
    """Remove temp files created during this session."""
    for filename in ['.session-files', '.session-context', '.relevant-skills']:
        path = os.path.join(memory_dir, filename)
        if os.path.exists(path):
            os.remove(path)
        # Also check agent dir
        path2 = os.path.join(agent_dir, filename)
        if os.path.exists(path2):
            os.remove(path2)


def write_dashboard_data(agent_slug, workspace_root, today, now):
    """Write channel metrics for frontend dashboard."""
    # Resolve agent's channel
    channel_path_file = os.path.join(workspace_root, 'agents', agent_slug, '.channel-path')
    if not os.path.exists(channel_path_file):
        return

    with open(channel_path_file, encoding='utf-8', errors='ignore') as f:
        channel_rel = f.read().strip()

    if not channel_rel:
        return

    channel_name = channel_rel.split('/')[-1] if '/' in channel_rel else channel_rel
    dashboard_dir = os.path.join(workspace_root, 'shared', 'dashboard', 'data')
    os.makedirs(dashboard_dir, exist_ok=True)

    # Read channel context.md for metrics
    context_path = os.path.join(workspace_root, channel_rel, 'context.md')
    context_summary = ''
    if os.path.exists(context_path):
        with open(context_path, encoding='utf-8', errors='ignore') as f:
            # Take first 500 chars as summary
            context_summary = f.read()[:500]

    # Count today's posts
    posts_path = os.path.join(workspace_root, channel_rel, 'output', 'posts.jsonl')
    today_posts = 0
    if os.path.exists(posts_path):
        with open(posts_path, encoding='utf-8', errors='ignore') as f:
            for line in f:
                if today in line:
                    today_posts += 1

    # Count today's deliverables
    deliverables_dir = os.path.join(workspace_root, channel_rel, 'output', 'deliverables')
    today_deliverables = 0
    if os.path.exists(deliverables_dir):
        today_deliverables = len(glob.glob(os.path.join(deliverables_dir, f'*{today}*')))

    dashboard = {
        'channel': channel_name,
        'updated_at': now,
        'metrics': {
            'posts_today': today_posts,
            'deliverables_today': today_deliverables,
        },
        'highlights': context_summary[:200] if context_summary else 'No context available',
    }

    dashboard_path = os.path.join(dashboard_dir, f'{channel_name}.json')
    with open(dashboard_path, 'w') as f:
        json.dump(dashboard, f, indent=2)


def rotate_activity_log(workspace_root, today):
    """Rotate activity.jsonl if it exceeds 1000 lines."""
    activity_path = os.path.join(workspace_root, 'shared', 'activity.jsonl')
    if not os.path.exists(activity_path):
        return

    with open(activity_path) as f:
        lines = f.readlines()

    if len(lines) > 1000:
        archive_dir = os.path.join(workspace_root, 'shared', 'archive')
        os.makedirs(archive_dir, exist_ok=True)
        archive_path = os.path.join(archive_dir, f'activity-{today}.jsonl')

        # Archive older entries, keep last 500
        with open(archive_path, 'a') as f:
            f.writelines(lines[:-500])

        with open(activity_path, 'w') as f:
            f.writelines(lines[-500:])


def clean_scratch(workspace_root):
    """Remove scratch files older than 1 day."""
    scratch_dir = os.path.join(workspace_root, 'scratch')
    if not os.path.exists(scratch_dir):
        return

    now_ts = datetime.now(timezone.utc).timestamp()
    one_day = 86400

    for item in os.listdir(scratch_dir):
        item_path = os.path.join(scratch_dir, item)
        try:
            mtime = os.path.getmtime(item_path)
            if now_ts - mtime > one_day:
                if os.path.isdir(item_path):
                    shutil.rmtree(item_path)
                else:
                    os.remove(item_path)
        except (OSError, IOError):
            continue


if __name__ == '__main__':
    main()
