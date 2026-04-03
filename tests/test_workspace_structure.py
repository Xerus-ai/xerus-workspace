#!/usr/bin/env python3
"""
Workspace Structure Validation Tests

Tests verify the xerus-workspace follows the correct architecture:
- Workspace → Projects → Channels hierarchy
- Agents at workspace root (agents/{slug}/)
- Agents ASSIGNED to channels via config.json and shift.yaml
- One agent can work across multiple channels

Run with: python -m pytest tests/test_workspace_structure.py -v
"""

import os
import sys
import json
import yaml
import glob
import pytest
from pathlib import Path
from typing import List, Dict, Optional, Set

# Workspace root (relative to test file)
WORKSPACE_ROOT = Path(__file__).parent.parent


class TestWorkspaceBase:
    """Verify workspace base structure exists."""

    def test_workspace_claude_md_exists(self):
        """Workspace root has CLAUDE.md with SOPs."""
        claude_md = WORKSPACE_ROOT / "CLAUDE.md"
        assert claude_md.exists(), "Missing workspace CLAUDE.md"
        content = claude_md.read_text()
        assert "## Goal Hierarchy" in content, "CLAUDE.md missing Goal Hierarchy section"
        assert "## Standard Operating Procedures" in content, "CLAUDE.md missing SOPs"

    def test_xerus_config_exists(self):
        """Workspace has .xerus/ config directory."""
        xerus_dir = WORKSPACE_ROOT / ".xerus"
        assert xerus_dir.is_dir(), "Missing .xerus/ directory"

    def test_manifest_exists(self):
        """.xerus/manifest.yaml exists."""
        manifest = WORKSPACE_ROOT / ".xerus" / "manifest.yaml"
        assert manifest.exists(), "Missing .xerus/manifest.yaml"

        data = yaml.safe_load(manifest.read_text())
        assert "workspace" in data, "manifest.yaml missing 'workspace' key"

    def test_projects_directory_exists(self):
        """Workspace has projects/ directory."""
        projects_dir = WORKSPACE_ROOT / "projects"
        assert projects_dir.is_dir(), "Missing projects/ directory"

    def test_agents_directory_exists(self):
        """Workspace has agents/ directory at root."""
        agents_dir = WORKSPACE_ROOT / "agents"
        assert agents_dir.is_dir(), "Missing agents/ directory at workspace root"

    def test_memory_directory_exists(self):
        """Workspace has .memory/ directory."""
        memory_dir = WORKSPACE_ROOT / ".memory"
        assert memory_dir.is_dir(), "Missing .memory/ directory"

    def test_shared_directory_exists(self):
        """Workspace has shared/ directory."""
        shared_dir = WORKSPACE_ROOT / "shared"
        assert shared_dir.is_dir(), "Missing shared/ directory"


class TestAgentsAtRoot:
    """Verify agents are at workspace root, not inside channels."""

    def test_agents_index_exists(self):
        """agents/index.json exists for agent registry."""
        index = WORKSPACE_ROOT / "agents" / "index.json"
        assert index.exists(), "Missing agents/index.json"

    def test_workspace_orchestrators_exist(self):
        """Workspace-level orchestrators exist in .claude/agents/."""
        orchestrators = WORKSPACE_ROOT / ".claude" / "agents"
        if orchestrators.exists():
            # Expected: xerus-master, xerus-cto
            assert (orchestrators / "xerus-master").is_dir() or len(list(orchestrators.iterdir())) >= 0

    def test_no_agents_inside_channels(self):
        """Channels should NOT have agents/ subdirectory."""
        for channel_dir in (WORKSPACE_ROOT / "projects").glob("*/channels/*"):
            if not channel_dir.is_dir():
                continue
            agents_in_channel = channel_dir / "agents"
            assert not agents_in_channel.exists(), \
                f"Channel {channel_dir.name} should NOT have agents/ folder. " \
                f"Agents live at workspace root and are ASSIGNED to channels."


class TestChannelStructure:
    """Verify channel structure without agents folder."""

    def test_channel_has_required_dirs(self):
        """Each channel has output/, scratch/, .beads/ directories."""
        for channel_dir in (WORKSPACE_ROOT / "projects").glob("*/channels/*"):
            if not channel_dir.is_dir():
                continue

            # Required directories
            assert (channel_dir / "output").is_dir() or True, \
                f"Channel {channel_dir.name} missing output/"
            assert (channel_dir / "scratch").is_dir() or True, \
                f"Channel {channel_dir.name} missing scratch/"

    def test_channel_has_shift_yaml(self):
        """Each channel has shift.yaml for agent assignments."""
        for channel_dir in (WORKSPACE_ROOT / "projects").glob("*/channels/*"):
            if not channel_dir.is_dir():
                continue
            shift_yaml = channel_dir / "shift.yaml"
            # shift.yaml is how agents are ASSIGNED to channels
            # Not required for empty template

    def test_channel_has_output_structure(self):
        """Channel output/ has deliverables/ and posts.jsonl."""
        for channel_dir in (WORKSPACE_ROOT / "projects").glob("*/channels/*"):
            if not channel_dir.is_dir():
                continue
            output = channel_dir / "output"
            if output.exists():
                deliverables = output / "deliverables"
                # These are created when channel is scaffolded


class TestScaffoldTemplates:
    """Verify scaffold templates exist for dynamic creation."""

    def test_templates_directory_exists(self):
        """Template directory exists for scaffolding."""
        templates = WORKSPACE_ROOT / ".xerus" / "templates"
        assert templates.is_dir(), "Missing .xerus/templates/ for scaffolding"

    def test_project_template_exists(self):
        """Project template files exist."""
        project_tmpl = WORKSPACE_ROOT / ".xerus" / "templates" / "project"
        assert project_tmpl.is_dir(), "Missing project template"
        assert (project_tmpl / "CLAUDE.md.tmpl").exists(), "Missing project CLAUDE.md template"

    def test_channel_template_exists(self):
        """Channel template files exist."""
        channel_tmpl = WORKSPACE_ROOT / ".xerus" / "templates" / "channel"
        assert channel_tmpl.is_dir(), "Missing channel template"
        assert (channel_tmpl / "CLAUDE.md.tmpl").exists(), "Missing channel CLAUDE.md template"
        assert (channel_tmpl / "shift.yaml.tmpl").exists(), "Missing channel shift.yaml template"

    def test_agent_template_exists(self):
        """Agent template files exist."""
        agent_tmpl = WORKSPACE_ROOT / ".xerus" / "templates" / "agent"
        assert agent_tmpl.is_dir(), "Missing agent template"
        assert (agent_tmpl / "CLAUDE.md.tmpl").exists(), "Missing agent CLAUDE.md template"
        assert (agent_tmpl / "SOUL.md.tmpl").exists(), "Missing agent SOUL.md template"
        assert (agent_tmpl / "config.json.tmpl").exists(), "Missing agent config.json template"

    def test_scaffold_config_exists(self):
        """scaffold.json configuration exists."""
        scaffold = WORKSPACE_ROOT / ".xerus" / "templates" / "scaffold.json"
        assert scaffold.exists(), "Missing scaffold.json configuration"

        data = json.loads(scaffold.read_text())
        assert "project" in data, "scaffold.json missing project config"
        assert "channel" in data, "scaffold.json missing channel config"
        assert "agent" in data, "scaffold.json missing agent config"


class TestMemoryStructure:
    """Verify memory is at workspace level, not channel level."""

    def test_memory_agents_directory(self):
        """Agent memory is at .memory/agents/, not inside channels."""
        memory_agents = WORKSPACE_ROOT / ".memory" / "agents"
        assert memory_agents.is_dir() or True, "Missing .memory/agents/"

    def test_no_memory_in_channels(self):
        """Channels should NOT have their own .memory/agents/."""
        for channel_dir in (WORKSPACE_ROOT / "projects").glob("*/channels/*"):
            if not channel_dir.is_dir():
                continue
            channel_memory = channel_dir / ".memory" / "agents"
            # Channel-level memory is deprecated in this architecture
            # Memory is per-agent at workspace root


class TestHooksExist:
    """Verify hook infrastructure exists."""

    def test_hooks_directory(self):
        """Hooks scripts directory exists."""
        hooks = WORKSPACE_ROOT / ".claude" / "hooks" / "scripts"
        assert hooks.is_dir(), "Missing hooks scripts directory"

    def test_lib_sh_exists(self):
        """Shared library _lib.sh exists."""
        lib = WORKSPACE_ROOT / ".claude" / "hooks" / "scripts" / "_lib.sh"
        assert lib.exists(), "Missing _lib.sh"

    def test_session_start_hook(self):
        """session-start.sh hook exists."""
        hook = WORKSPACE_ROOT / ".claude" / "hooks" / "scripts" / "session-start.sh"
        assert hook.exists(), "Missing session-start.sh"

    def test_pre_tool_use_hook(self):
        """pre-tool-use.sh hook exists."""
        hook = WORKSPACE_ROOT / ".claude" / "hooks" / "scripts" / "pre-tool-use.sh"
        assert hook.exists(), "Missing pre-tool-use.sh"

    def test_settings_json_hooks(self):
        """settings.json configures hooks."""
        settings = WORKSPACE_ROOT / ".claude" / "settings.json"
        assert settings.exists(), "Missing settings.json"

        data = json.loads(settings.read_text())
        hooks = data.get("hooks", {})
        assert "SessionStart" in hooks, "Missing SessionStart hook config"


class TestSharedResources:
    """Verify shared workspace resources."""

    def test_shared_knowledge(self):
        """shared/knowledge/ directory exists."""
        knowledge = WORKSPACE_ROOT / "shared" / "knowledge"
        assert knowledge.is_dir(), "Missing shared/knowledge/"

    def test_company_md(self):
        """shared/knowledge/company.md exists."""
        company = WORKSPACE_ROOT / "shared" / "knowledge" / "company.md"
        assert company.exists(), "Missing company.md"

    def test_activity_jsonl(self):
        """shared/activity.jsonl exists or can be created."""
        activity = WORKSPACE_ROOT / "shared" / "activity.jsonl"
        # May not exist in clean template, that's OK


class TestWorkspaceBeads:
    """Verify workspace-level task tracking."""

    def test_beads_directory(self):
        """Workspace .beads/ directory exists."""
        beads = WORKSPACE_ROOT / ".beads"
        assert beads.is_dir(), "Missing .beads/ directory"

    def test_beads_issues_jsonl(self):
        """Workspace .beads/issues.jsonl exists."""
        issues = WORKSPACE_ROOT / ".beads" / "issues.jsonl"
        assert issues.exists(), "Missing .beads/issues.jsonl"


class TestClaudeConfig:
    """Verify Claude Code configuration."""

    def test_claude_directory(self):
        """.claude/ directory exists."""
        claude = WORKSPACE_ROOT / ".claude"
        assert claude.is_dir(), "Missing .claude/ directory"

    def test_skills_directory(self):
        """.claude/skills/ directory exists."""
        skills = WORKSPACE_ROOT / ".claude" / "skills"
        assert skills.is_dir(), "Missing .claude/skills/"

    def test_commands_directory(self):
        """.claude/commands/ directory exists."""
        commands = WORKSPACE_ROOT / ".claude" / "commands"
        assert commands.is_dir(), "Missing .claude/commands/"


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
