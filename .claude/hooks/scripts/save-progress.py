#!/usr/bin/env python3
"""Save agent progress to working.md before context compaction or interruption.

Reads .task-context.md and .session-files to build a structured summary
that the agent can re-read after compaction to resume where it left off.

Usage:
    python3 save-progress.py <agent_slug> <workspace_root> [--interrupted]
"""

import sys
import os
from datetime import datetime, timezone


def main():
    if len(sys.argv) < 3:
        return

    agent_slug = sys.argv[1]
    workspace_root = sys.argv[2]
    interrupted = '--interrupted' in sys.argv
    now = datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')

    memory_dir = os.path.join(workspace_root, '.memory', 'agents', agent_slug)
    working_path = os.path.join(memory_dir, 'working.md')
    task_context_path = os.path.join(memory_dir, '.task-context.md')
    session_files_path = os.path.join(memory_dir, '.session-files')

    # Read current task context
    task_info = ''
    task_id = ''
    task_title = ''
    if os.path.exists(task_context_path):
        with open(task_context_path, encoding='utf-8', errors='ignore') as f:
            content = f.read()
            task_info = content
            for line in content.split('\n'):
                if line.startswith('**ID**:'):
                    task_id = line.replace('**ID**:', '').strip()
                if line.startswith('**Title**:'):
                    task_title = line.replace('**Title**:', '').strip()

    # Read session files (what was touched)
    files_touched = []
    if os.path.exists(session_files_path):
        with open(session_files_path, encoding='utf-8', errors='ignore') as f:
            files_touched = [line.strip() for line in f if line.strip()]

    # Read existing working.md to preserve history
    existing_content = ''
    if os.path.exists(working_path):
        with open(working_path, encoding='utf-8', errors='ignore') as f:
            existing_content = f.read()

    # Preserve previous session summaries (keep last 3)
    prev_sessions = []
    if '## Last Session' in existing_content or '## Previous Sessions' in existing_content:
        # Extract previous session blocks
        lines = existing_content.split('\n')
        in_prev = False
        current_block = []
        for line in lines:
            if line.startswith('## Last Session') or line.startswith('## Previous Session'):
                if current_block:
                    prev_sessions.append('\n'.join(current_block))
                current_block = [line]
                in_prev = True
            elif in_prev and line.startswith('## ') and not line.startswith('## Last') and not line.startswith('## Previous'):
                if current_block:
                    prev_sessions.append('\n'.join(current_block))
                in_prev = False
                current_block = []
            elif in_prev:
                current_block.append(line)
        if current_block:
            prev_sessions.append('\n'.join(current_block))

    # Build the new working.md
    status = 'INTERRUPTED' if interrupted else 'in progress (compacted)'

    with open(working_path, 'w') as f:
        f.write(f"# Working Memory -- {agent_slug}\n\n")

        f.write(f"## Current Session ({status} at {now})\n")
        if task_id:
            f.write(f"Task: {task_id} \"{task_title}\"\n")
            f.write(f"Status: {status}\n")
        else:
            f.write(f"No task assigned. Self-directed work.\n")

        if files_touched:
            f.write(f"\n### Files Touched\n")
            # Deduplicate and show last 20
            seen = set()
            unique = []
            for ft in reversed(files_touched):
                if ft not in seen:
                    seen.add(ft)
                    unique.append(ft)
            for ft in reversed(unique[-20:]):
                f.write(f"- {ft}\n")

        if interrupted:
            f.write(f"\n### Resume Instructions\n")
            f.write(f"Session was interrupted. Task is NOT closed.\n")
            f.write(f"Re-read .task-context.md and continue from where you left off.\n")
            if task_id:
                f.write(f"When done: `bd close {task_id} --reason \"your summary\"`\n")
        else:
            f.write(f"\n### Resume After Compaction\n")
            f.write(f"Context was compacted. Re-read this file to resume.\n")
            f.write(f"Your task and progress are described above.\n")
            if task_id:
                f.write(f"Continue working on {task_id}. Close when done.\n")

        # Keep last 2 previous sessions for history
        if prev_sessions:
            f.write(f"\n## Previous Sessions\n")
            for ps in prev_sessions[-2:]:
                # Strip the header and re-add as sub-section
                ps_lines = ps.split('\n')
                for pl in ps_lines:
                    if pl.startswith('## '):
                        f.write(f"### {pl[3:]}\n")
                    else:
                        f.write(f"{pl}\n")
                f.write("\n")


if __name__ == '__main__':
    main()
