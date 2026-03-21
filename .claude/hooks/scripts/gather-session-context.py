#!/usr/bin/env python3
"""Gather session context: match skills, read memory, check inbox.

Prepares a warm start for the agent by collecting relevant context
from the workspace before the agent starts thinking.

Writes:
  .memory/agents/{slug}/.session-context  (summary for agent to read)
  .memory/agents/{slug}/.relevant-skills  (matched skill paths)

Usage:
    python3 gather-session-context.py <agent_slug> <workspace_root>
"""

import sys
import os
import json
import glob
from datetime import datetime, timezone


def main():
    if len(sys.argv) < 3:
        return

    agent_slug = sys.argv[1]
    workspace_root = sys.argv[2]

    memory_dir = os.path.join(workspace_root, '.memory', 'agents', agent_slug)
    agent_dir = os.path.join(workspace_root, 'agents', agent_slug)

    os.makedirs(memory_dir, exist_ok=True)

    # ── 1. Read task context for keywords ──
    task_keywords = extract_task_keywords(memory_dir)

    # ── 2. Match installed skills ──
    matched_skills = match_skills(workspace_root, task_keywords)

    # ── 3. Read previous session state ──
    prev_session = read_working_memory(memory_dir)

    # ── 4. Check inbox for unread messages ──
    inbox_messages = check_inbox(agent_dir)

    # ── 5. Search for related entities ──
    related_entities = search_entities(workspace_root, task_keywords)

    # ── 6. Write .relevant-skills ──
    skills_path = os.path.join(memory_dir, '.relevant-skills')
    with open(skills_path, 'w') as f:
        if matched_skills:
            for name, path in matched_skills:
                f.write(f"{name}: {path}\n")
        else:
            f.write("No skill matches found for current task.\n")

    # ── 7. Write .session-context ──
    context_path = os.path.join(memory_dir, '.session-context')
    with open(context_path, 'w') as f:
        f.write(f"# Session Context -- {agent_slug}\n")
        f.write(f"Generated: {datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')}\n\n")

        if prev_session:
            f.write(f"## Previous Session\n{prev_session}\n\n")

        if inbox_messages:
            f.write(f"## Inbox ({len(inbox_messages)} unread)\n")
            for msg in inbox_messages[:5]:
                f.write(f"- {msg}\n")
            f.write("\n")

        if matched_skills:
            f.write(f"## Suggested Skills\n")
            for name, path in matched_skills[:5]:
                f.write(f"- **{name}**: `{path}`\n")
            f.write("\n")

        if related_entities:
            f.write(f"## Related Entities\n")
            for entity_path in related_entities[:5]:
                f.write(f"- {entity_path}\n")
            f.write("\n")

        if not any([prev_session, inbox_messages, matched_skills, related_entities]):
            f.write("No additional context found. Proceed with task.\n")


def extract_task_keywords(memory_dir):
    """Extract keywords from .task-context.md for skill matching."""
    task_path = os.path.join(memory_dir, '.task-context.md')
    if not os.path.exists(task_path):
        return []

    with open(task_path) as f:
        content = f.read().lower()

    # Extract meaningful words (skip common words)
    stop_words = {'the', 'a', 'an', 'is', 'are', 'was', 'were', 'be', 'been',
                  'being', 'have', 'has', 'had', 'do', 'does', 'did', 'will',
                  'would', 'could', 'should', 'may', 'might', 'must', 'shall',
                  'can', 'need', 'dare', 'ought', 'used', 'to', 'of', 'in',
                  'for', 'on', 'with', 'at', 'by', 'from', 'as', 'into',
                  'through', 'during', 'before', 'after', 'above', 'below',
                  'between', 'and', 'but', 'or', 'nor', 'not', 'so', 'yet',
                  'both', 'either', 'neither', 'each', 'every', 'all', 'any',
                  'few', 'more', 'most', 'other', 'some', 'such', 'no', 'only',
                  'own', 'same', 'than', 'too', 'very', 'just', 'your', 'this',
                  'that', 'these', 'those', 'it', 'its', 'you', 'your', 'my'}

    words = set()
    for word in content.split():
        word = word.strip('*#-[]().,:"\'`')
        if len(word) > 3 and word not in stop_words and word.isalpha():
            words.add(word)

    return list(words)


def match_skills(workspace_root, keywords):
    """Match keywords against installed skill names and descriptions."""
    skills_dir = os.path.join(workspace_root, '.claude', 'skills')
    if not os.path.exists(skills_dir):
        return []

    matched = []
    for skill_dir in os.listdir(skills_dir):
        skill_path = os.path.join(skills_dir, skill_dir, 'SKILL.md')
        if not os.path.exists(skill_path):
            continue

        # Match against skill directory name
        skill_name = skill_dir.lower()
        score = 0

        # Read header once per skill (not per keyword)
        try:
            with open(skill_path, encoding='utf-8', errors='ignore') as f:
                header = ''.join(f.readline() for _ in range(5)).lower()
        except (IOError, OSError):
            header = ''

        for kw in keywords:
            if kw in skill_name or skill_name in kw:
                score += 2
            if kw in header:
                score += 1

        if score > 0:
            rel_path = f".claude/skills/{skill_dir}/SKILL.md"
            matched.append((skill_dir, rel_path, score))

    # Sort by score descending
    matched.sort(key=lambda x: x[2], reverse=True)
    return [(name, path) for name, path, _ in matched[:10]]


def read_working_memory(memory_dir):
    """Read last session summary from working.md."""
    working_path = os.path.join(memory_dir, 'working.md')
    if not os.path.exists(working_path):
        return ''

    with open(working_path) as f:
        content = f.read()

    # Extract last session section (first 300 chars)
    if '## Last Session' in content:
        idx = content.index('## Last Session')
        section = content[idx:idx + 300]
        return section.strip()

    return content[:200].strip() if content.strip() else ''


def check_inbox(agent_dir):
    """Check for unread messages in agent inbox."""
    inbox_dir = os.path.join(agent_dir, 'inbox')
    if not os.path.exists(inbox_dir):
        return []

    messages = []
    for fname in sorted(os.listdir(inbox_dir)):
        if fname == 'processed' or fname.startswith('.'):
            continue
        fpath = os.path.join(inbox_dir, fname)
        if os.path.isfile(fpath):
            try:
                with open(fpath) as f:
                    msg = json.load(f)
                sender = msg.get('from', msg.get('agent', 'unknown'))
                content = msg.get('content', msg.get('message', ''))[:100]
                messages.append(f"From {sender}: {content}")
            except (json.JSONDecodeError, IOError):
                messages.append(f"Unread: {fname}")

    return messages


def search_entities(workspace_root, keywords):
    """Search .memory/entities/ for files matching task keywords."""
    entities_dir = os.path.join(workspace_root, '.memory', 'entities')
    if not os.path.exists(entities_dir):
        return []

    matched = []
    for pattern in ['**/*.md']:
        for filepath in glob.glob(os.path.join(entities_dir, pattern), recursive=True):
            filename = os.path.basename(filepath).lower().replace('.md', '').replace('-', ' ')
            for kw in keywords:
                if kw in filename:
                    rel = os.path.relpath(filepath, workspace_root)
                    matched.append(rel)
                    break

    return matched[:10]


if __name__ == '__main__':
    main()
