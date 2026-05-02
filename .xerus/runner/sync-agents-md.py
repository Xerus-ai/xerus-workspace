#!/usr/bin/env python3
"""Generate AGENTS.md from agent registry + openskills skill registry.

Combines:
1. Agent registry (agents/index.json or agents/*/agent.yaml)
2. Skill registry (.agent/skills/*/SKILL.md frontmatter)
3. Workspace SOPs (extracted from root CLAUDE.md)

Output: AGENTS.md at workspace root (the universal entry point for all adapters).

Usage: python3 sync-agents-md.py <workspace_root>
"""
import json
import os
import sys
from datetime import datetime, timezone
from pathlib import Path


def read_agent_index(workspace: Path) -> dict:
    """Read agents from index.json."""
    index_file = workspace / "agents" / "index.json"
    if not index_file.exists():
        return {}
    with open(index_file) as f:
        data = json.load(f)
    return data.get("agents", {})


def read_agent_yaml(agent_dir: Path) -> dict | None:
    """Read agent.yaml (gitagent format) and extract metadata."""
    yaml_file = agent_dir / "agent.yaml"
    if not yaml_file.exists():
        return None
    result = {"name": "", "role": "", "model": "", "domain": "", "primary_channel": ""}
    with open(yaml_file) as f:
        for line in f:
            line = line.strip()
            if line.startswith("name:"):
                result["name"] = line.split(":", 1)[1].strip().strip('"')
            elif line.startswith("description:"):
                result["role"] = line.split(":", 1)[1].strip().strip('"')
            elif line.startswith("  preferred:"):
                result["model"] = line.split(":", 1)[1].strip().strip('"')
            elif line.startswith("  display_name:"):
                result["name"] = line.split(":", 1)[1].strip().strip('"')
            elif line.startswith("  role:"):
                result["role"] = line.split(":", 1)[1].strip().strip('"')
            elif line.startswith("  domain:"):
                result["domain"] = line.split(":", 1)[1].strip().strip('"')
            elif line.startswith("  primary_channel:"):
                result["primary_channel"] = line.split(":", 1)[1].strip().strip('"')
    return result


def discover_agents(workspace: Path) -> list[dict]:
    """Discover all agents from filesystem."""
    agents = []
    agents_dir = workspace / "agents"
    if not agents_dir.is_dir():
        return agents

    index = read_agent_index(workspace)

    for entry in sorted(agents_dir.iterdir()):
        if not entry.is_dir() or entry.name.startswith("."):
            continue
        slug = entry.name

        agent_info = read_agent_yaml(entry)
        if agent_info is None and slug in index:
            agent_info = index[slug]
        if agent_info is None:
            config_file = entry / "config.json"
            if config_file.exists():
                with open(config_file) as f:
                    cfg = json.load(f)
                agent_info = {
                    "name": cfg.get("name", slug),
                    "role": cfg.get("role", cfg.get("description", "")),
                    "model": cfg.get("model", ""),
                    "domain": cfg.get("domain", ""),
                    "primary_channel": cfg.get("primary_channel", ""),
                }

        if agent_info is None:
            continue

        agents.append({"slug": slug, **agent_info})

    return agents


def discover_skills(workspace: Path) -> list[dict]:
    """Discover installed openskills from .agent/skills/."""
    skills = []
    skills_dir = workspace / ".agent" / "skills"
    if not skills_dir.is_dir():
        skills_dir = workspace / ".claude" / "skills"
    if not skills_dir.is_dir():
        return skills

    for entry in sorted(skills_dir.iterdir()):
        if not entry.is_dir() or entry.name.startswith("."):
            continue
        skill_md = entry / "SKILL.md"
        if not skill_md.exists():
            continue

        name = entry.name
        description = ""
        when_to_use = ""
        with open(skill_md) as f:
            in_when = False
            for line in f:
                if line.startswith("# "):
                    description = line[2:].strip()
                elif line.strip().lower().startswith("## when to use"):
                    in_when = True
                elif in_when and line.startswith("## "):
                    in_when = False
                elif in_when and line.strip().startswith("- "):
                    if not when_to_use:
                        when_to_use = line.strip()[2:]

        skills.append({
            "slug": name,
            "name": description or name,
            "when_to_use": when_to_use,
        })

    return skills


def generate_agents_md(workspace: Path) -> str:
    """Generate the AGENTS.md content."""
    agents = discover_agents(workspace)
    skills = discover_skills(workspace)
    ts = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

    lines = [
        "# AGENTS.md",
        "",
        f"Auto-generated at {ts} by sync-agents-md.py. Do not edit manually.",
        "",
    ]

    lines.append("<agents_system>")
    lines.append("")
    if agents:
        lines.append("| Slug | Name | Role | Channel | Model |")
        lines.append("|------|------|------|---------|-------|")
        for a in agents:
            lines.append(
                f"| {a['slug']} | {a.get('name', '')} | {a.get('role', '')} "
                f"| {a.get('primary_channel', '')} | {a.get('model', '')} |"
            )
    else:
        lines.append("No agents registered yet.")
    lines.append("")
    lines.append("</agents_system>")
    lines.append("")

    lines.append("<skills_system>")
    lines.append("")
    if skills:
        lines.append("| Skill | Description | Use When |")
        lines.append("|-------|-------------|----------|")
        for s in skills:
            lines.append(f"| {s['slug']} | {s['name']} | {s['when_to_use']} |")
    else:
        lines.append("No skills installed yet. Use `.agent/skills/` (openskills) to add skills.")
    lines.append("")
    lines.append("</skills_system>")
    lines.append("")

    return "\n".join(lines)


def main():
    if len(sys.argv) < 2:
        print("Usage: sync-agents-md.py <workspace_root>", file=sys.stderr)
        sys.exit(1)

    workspace = Path(sys.argv[1])
    if not workspace.is_dir():
        print(f"Workspace not found: {workspace}", file=sys.stderr)
        sys.exit(1)

    content = generate_agents_md(workspace)
    output_path = workspace / "AGENTS.md"
    with open(output_path, "w") as f:
        f.write(content)

    print(f"AGENTS.md generated with {len(discover_agents(workspace))} agents, {len(discover_skills(workspace))} skills")


if __name__ == "__main__":
    main()
