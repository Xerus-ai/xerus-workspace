#!/usr/bin/env python3
"""
Fail-fast agent identity tests for the Xerus shell hooks.

Verifies that activity/audit writes refuse to run (and emit a loud error) when
XERUS_AGENT_SLUG is missing/empty, and behave normally when it is set. Exercises
the real bash in .claude/hooks/scripts/_lib.sh, the post-tool-use direct writer,
and the historical cleanup script — no mocks, real filesystem.

Run with: python -m pytest tests/test_hook_agent_identity.py -v
"""

import json
import os
import shutil
import subprocess
from pathlib import Path

import pytest

WORKSPACE_ROOT = Path(__file__).parent.parent
SCRIPTS = WORKSPACE_ROOT / ".claude" / "hooks" / "scripts"
LIB = SCRIPTS / "_lib.sh"
POST_TOOL_USE = SCRIPTS / "post-tool-use.sh"
CLEANUP = SCRIPTS / "cleanup-activity-identity.sh"

BASH = shutil.which("bash")

pytestmark = pytest.mark.skipif(BASH is None, reason="bash not available on this host")


def _workspace(tmp_path):
    (tmp_path / "data").mkdir(exist_ok=True)
    (tmp_path / ".xerus").mkdir(exist_ok=True)
    return tmp_path


def _env(tmp_path, slug=None):
    env = {"XERUS_WORKSPACE_ROOT": str(tmp_path), "PATH": os.environ.get("PATH", "")}
    if slug is not None:
        env["XERUS_AGENT_SLUG"] = slug
    return env


def _run_lib(tmp_path, snippet, slug=None):
    """Source _lib.sh in a fresh workspace and run a bash snippet."""
    _workspace(tmp_path)
    script = f'source "{LIB}"\n{snippet}\n'
    return subprocess.run(
        [BASH, "-c", script], capture_output=True, text=True, env=_env(tmp_path, slug)
    )


def _activity(tmp_path):
    f = tmp_path / "data" / "activity.jsonl"
    if not f.exists():
        return []
    return [json.loads(line) for line in f.read_text().splitlines() if line.strip()]


def _audit(tmp_path):
    f = tmp_path / ".xerus" / "hook-audit.jsonl"
    if not f.exists():
        return []
    return [json.loads(line) for line in f.read_text().splitlines() if line.strip()]


# --- log_activity ---------------------------------------------------------


def test_log_activity_writes_with_valid_slug(tmp_path):
    r = _run_lib(tmp_path, 'log_activity "session_start"; echo "RC:$?"', slug="market-analyst")
    assert "RC:0" in r.stdout
    rows = _activity(tmp_path)
    assert len(rows) == 1
    assert rows[0]["event"] == "session_start"
    assert rows[0]["agent"] == "market-analyst"


def test_log_activity_refuses_when_unset(tmp_path):
    r = _run_lib(tmp_path, 'log_activity "session_start"; echo "RC:$?"', slug=None)
    assert "RC:1" in r.stdout
    assert _activity(tmp_path) == []
    assert "refusing to write activity" in r.stderr
    assert "XERUS_AGENT_SLUG" in r.stderr


def test_log_activity_refuses_when_empty(tmp_path):
    r = _run_lib(tmp_path, 'log_activity "session_start"; echo "RC:$?"', slug="")
    assert "RC:1" in r.stdout
    assert _activity(tmp_path) == []
    assert "refusing to write activity" in r.stderr


def test_log_activity_never_writes_literal_unknown(tmp_path):
    # The whole point: a missing identity must NOT become agent "unknown".
    _run_lib(tmp_path, 'log_activity "session_start"', slug=None)
    for row in _activity(tmp_path):
        assert row["agent"] != "unknown"
    assert _activity(tmp_path) == []


def test_log_activity_explicit_system_slug_wins(tmp_path):
    # session-start.sh logs scheduler events as the "system" pseudo-agent while
    # the env var still identifies the real agent — explicit arg must win.
    r = _run_lib(
        tmp_path, 'log_activity "scheduler_started" "system"; echo "RC:$?"', slug="real-agent"
    )
    assert "RC:0" in r.stdout
    rows = _activity(tmp_path)
    assert rows[0]["agent"] == "system"


# --- audit ----------------------------------------------------------------


def test_audit_writes_with_valid_slug(tmp_path):
    r = _run_lib(tmp_path, 'audit "SessionStart"; echo "RC:$?"', slug="repo-scout")
    assert "RC:0" in r.stdout
    rows = _audit(tmp_path)
    assert len(rows) == 1
    assert rows[0]["hook"] == "SessionStart"
    assert rows[0]["agent"] == "repo-scout"


def test_audit_refuses_when_unset(tmp_path):
    r = _run_lib(tmp_path, 'audit "SessionStart"; echo "RC:$?"', slug=None)
    assert "RC:1" in r.stdout
    assert _audit(tmp_path) == []
    assert "refusing to write activity" in r.stderr


# --- header-level format validation (source-time) -------------------------


def test_invalid_slug_aborts_on_source(tmp_path):
    r = _run_lib(tmp_path, 'log_activity "x"', slug="bad slug!")
    assert r.returncode == 1
    assert "Invalid XERUS_AGENT_SLUG" in r.stderr
    assert _activity(tmp_path) == []


# --- post-tool-use.sh direct writer --------------------------------------


def _run_post_tool_use(tmp_path, slug=None):
    _workspace(tmp_path)
    payload = json.dumps({"tool_name": "Write", "tool_input": {"file_path": "/w/report.md"}})
    return subprocess.run(
        [BASH, str(POST_TOOL_USE)],
        input=payload,
        capture_output=True,
        text=True,
        env=_env(tmp_path, slug),
    )


def test_post_tool_use_writes_file_event_with_slug(tmp_path):
    _run_post_tool_use(tmp_path, slug="trend-hunter")
    rows = [r for r in _activity(tmp_path) if r.get("event") == "file_write"]
    assert len(rows) == 1
    assert rows[0]["agent"] == "trend-hunter"
    assert rows[0]["path"] == "/w/report.md"


def test_post_tool_use_refuses_file_event_without_slug(tmp_path):
    r = _run_post_tool_use(tmp_path, slug=None)
    assert [row for row in _activity(tmp_path) if row.get("event") == "file_write"] == []
    assert "refusing to write activity" in r.stderr


# --- historical cleanup script -------------------------------------------


def test_cleanup_removes_unknown_and_empty_keeps_valid(tmp_path):
    _workspace(tmp_path)
    activity = tmp_path / "data" / "activity.jsonl"
    activity.write_text(
        "\n".join(
            [
                json.dumps({"event": "session_start", "agent": "market-analyst", "timestamp": "t1"}),
                json.dumps({"event": "session_start", "agent": "unknown", "timestamp": "t2"}),
                json.dumps({"event": "session_start", "agent": "", "timestamp": "t3"}),
                json.dumps({"event": "session_start", "agent": "repo-scout", "timestamp": "t4"}),
            ]
        )
        + "\n"
    )
    r = subprocess.run(
        [BASH, str(CLEANUP), str(tmp_path)],
        capture_output=True,
        text=True,
        env=_env(tmp_path),
    )
    assert r.returncode == 0, r.stderr
    agents = sorted(row["agent"] for row in _activity(tmp_path))
    assert agents == ["market-analyst", "repo-scout"]


def test_cleanup_is_idempotent(tmp_path):
    _workspace(tmp_path)
    activity = tmp_path / "data" / "activity.jsonl"
    activity.write_text(
        json.dumps({"event": "e", "agent": "unknown", "timestamp": "t"}) + "\n"
        + json.dumps({"event": "e", "agent": "market-analyst", "timestamp": "t"}) + "\n"
    )
    env = _env(tmp_path)
    subprocess.run([BASH, str(CLEANUP), str(tmp_path)], capture_output=True, text=True, env=env)
    first = _activity(tmp_path)
    r2 = subprocess.run(
        [BASH, str(CLEANUP), str(tmp_path)], capture_output=True, text=True, env=env
    )
    assert "removed 0 unknown/empty entries" in r2.stdout
    assert _activity(tmp_path) == first


def test_cleanup_requires_workspace_root(tmp_path):
    r = subprocess.run(
        [BASH, str(CLEANUP)], capture_output=True, text=True, env={"PATH": os.environ.get("PATH", "")}
    )
    assert r.returncode == 1
    assert "workspace root not provided" in r.stderr
