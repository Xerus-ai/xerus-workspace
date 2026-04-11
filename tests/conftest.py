#!/usr/bin/env python3
"""
Pytest configuration for workspace tests.
"""

import os
import sys
from pathlib import Path

import pytest

# Add workspace root to path
WORKSPACE_ROOT = Path(__file__).parent.parent
sys.path.insert(0, str(WORKSPACE_ROOT))


@pytest.fixture
def workspace_root():
    """Return the workspace root path."""
    return WORKSPACE_ROOT


@pytest.fixture
def projects_dir(workspace_root):
    """Return the projects directory."""
    return workspace_root / "projects"


@pytest.fixture
def drive_dir(workspace_root):
    """Return the drive directory (user content)."""
    return workspace_root / "drive"


@pytest.fixture
def rules_dir(workspace_root):
    """Return the .claude/rules directory (governance policies)."""
    return workspace_root / ".claude" / "rules"


@pytest.fixture
def claude_dir(workspace_root):
    """Return the .claude directory."""
    return workspace_root / ".claude"
