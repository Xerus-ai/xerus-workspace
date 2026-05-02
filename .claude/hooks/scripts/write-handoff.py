#!/usr/bin/env python3
"""Write shift handoff file for the next agent in the channel.

Reads the agent's working.md and recent session activity to produce
a handoff markdown file in .channel/state/handoffs/.

Usage: python3 write-handoff.py <agent_slug> <workspace_root> <handoff_dir>
"""
import json
import os
import sys
from datetime import datetime, timezone
from pathlib import Path


def read_working_md(workspace: Path, agent_slug: str) -> str:
    """Read agent's working.md for current state."""
    working = workspace / ".memory" / "agents" / agent_slug / "working.md"
    if not working.exists():
        return ""
    return working.read_text(encoding="utf-8")


def read_recent_posts(workspace: Path, agent_slug: str) -> list[str]:
    """Read agent's recent posts from their channel."""
    agent_config = workspace / "agents" / agent_slug / "config.json"
    if not agent_config.exists():
        return []

    try:
        with open(agent_config) as f:
            config = json.load(f)
    except (json.JSONDecodeError, OSError):
        return []

    domain = config.get("domain", "")
    channel = config.get("primary_channel", "")
    if not domain or not channel:
        return []

    posts_file = workspace / "projects" / domain / "channels" / channel / "output" / "posts.jsonl"
    if not posts_file.exists():
        return []

    recent = []
    try:
        with open(posts_file) as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    post = json.loads(line)
                    if post.get("agent_slug") == agent_slug:
                        recent.append(post.get("content", ""))
                except json.JSONDecodeError:
                    continue
    except OSError:
        return []

    return recent[-5:]


def generate_handoff(agent_slug: str, working_content: str, recent_posts: list[str]) -> str:
    """Generate handoff markdown."""
    ts = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    lines = [
        f"# Shift Handoff from {agent_slug}",
        f"Generated: {ts}",
        "",
    ]

    lines.append("## Working State")
    if working_content:
        for line in working_content.split("\n"):
            if line.startswith("# "):
                continue
            lines.append(line)
    else:
        lines.append("No working state recorded.")
    lines.append("")

    lines.append("## Recent Activity")
    if recent_posts:
        for post in recent_posts:
            lines.append(f"- {post[:200]}")
    else:
        lines.append("No recent posts.")
    lines.append("")

    return "\n".join(lines)


def main():
    if len(sys.argv) < 4:
        print("Usage: write-handoff.py <agent_slug> <workspace_root> <handoff_dir>", file=sys.stderr)
        sys.exit(1)

    agent_slug = sys.argv[1]
    workspace = Path(sys.argv[2])
    handoff_dir = Path(sys.argv[3])

    working_content = read_working_md(workspace, agent_slug)
    recent_posts = read_recent_posts(workspace, agent_slug)

    if not working_content and not recent_posts:
        sys.exit(0)

    handoff_dir.mkdir(parents=True, exist_ok=True)

    ts = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S")
    filename = f"handoff-{agent_slug}-{ts}.md"
    handoff_path = handoff_dir / filename

    content = generate_handoff(agent_slug, working_content, recent_posts)
    handoff_path.write_text(content, encoding="utf-8")

    # Retain only the latest 10 handoffs per agent
    import glob as glob_mod
    pattern = str(handoff_dir / f"handoff-{agent_slug}-*.md")
    existing = sorted(glob_mod.glob(pattern), reverse=True)
    for old_file in existing[10:]:
        try:
            Path(old_file).unlink()
        except OSError:
            pass

    print(f"Handoff written: {filename}")


if __name__ == "__main__":
    main()
