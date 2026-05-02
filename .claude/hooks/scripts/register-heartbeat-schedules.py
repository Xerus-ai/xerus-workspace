#!/usr/bin/env python3
"""Parse HEARTBEAT.md and register schedules in workspace.db.

Reads the Scheduled section of an agent's HEARTBEAT.md, converts
human-readable frequency descriptions to cron expressions, and
INSERTs them into the workspace.db schedules table.

Usage: python3 register-heartbeat-schedules.py <agent_slug> <heartbeat_path> <workspace_root>
"""
import os
import re
import sqlite3
import sys
from datetime import datetime, timezone
from pathlib import Path

FREQUENCY_TO_CRON = {
    "daily 9:00 am": "0 9 * * *",
    "daily 9:00am": "0 9 * * *",
    "daily 5:00 pm": "0 17 * * *",
    "daily 5:00pm": "0 17 * * *",
    "daily 8:00 am": "0 8 * * *",
    "daily 8:00am": "0 8 * * *",
    "daily 6:00 pm": "0 18 * * *",
    "daily 6:00pm": "0 18 * * *",
    "daily 10:00 am": "0 10 * * *",
    "daily 10:00am": "0 10 * * *",
    "daily noon": "0 12 * * *",
    "daily 12:00 pm": "0 12 * * *",
    "hourly": "0 * * * *",
    "every 30 minutes": "*/30 * * * *",
    "every 15 minutes": "*/15 * * * *",
    "weekly monday 9:00 am": "0 9 * * 1",
    "weekly friday 5:00 pm": "0 17 * * 5",
}

GENERIC_DAILY_PATTERN = re.compile(
    r"daily\s+(\d{1,2}):(\d{2})\s*(am|pm)?",
    re.IGNORECASE,
)

GENERIC_WEEKLY_PATTERN = re.compile(
    r"weekly\s+(monday|tuesday|wednesday|thursday|friday|saturday|sunday)\s+(\d{1,2}):(\d{2})\s*(am|pm)?",
    re.IGNORECASE,
)

DAY_TO_CRON = {
    "monday": "1", "tuesday": "2", "wednesday": "3",
    "thursday": "4", "friday": "5", "saturday": "6", "sunday": "0",
}


def frequency_to_cron(freq: str) -> str | None:
    """Convert a human-readable frequency to a cron expression."""
    normalized = freq.strip().lower()
    if normalized in FREQUENCY_TO_CRON:
        return FREQUENCY_TO_CRON[normalized]

    m = GENERIC_DAILY_PATTERN.match(normalized)
    if m:
        hour = int(m.group(1))
        minute = int(m.group(2))
        ampm = (m.group(3) or "").lower()
        if ampm == "pm" and hour < 12:
            hour += 12
        elif ampm == "am" and hour == 12:
            hour = 0
        return f"{minute} {hour} * * *"

    m = GENERIC_WEEKLY_PATTERN.match(normalized)
    if m:
        day = m.group(1).lower()
        hour = int(m.group(2))
        minute = int(m.group(3))
        ampm = (m.group(4) or "").lower()
        if ampm == "pm" and hour < 12:
            hour += 12
        elif ampm == "am" and hour == 12:
            hour = 0
        return f"{minute} {hour} * * {DAY_TO_CRON[day]}"

    return None


def parse_heartbeat(heartbeat_path: Path) -> list[dict]:
    """Parse HEARTBEAT.md and extract scheduled entries."""
    if not heartbeat_path.exists():
        return []

    entries = []
    in_scheduled = False
    with open(heartbeat_path) as f:
        for line in f:
            stripped = line.strip()
            if stripped.lower().startswith("## scheduled"):
                in_scheduled = True
                continue
            if stripped.startswith("## ") and in_scheduled:
                in_scheduled = False
                continue
            if not in_scheduled:
                continue
            if not stripped.startswith("- **"):
                continue

            m = re.match(r"-\s+\*\*(.+?)\*\*:\s*(.+)", stripped)
            if not m:
                continue

            frequency_str = m.group(1).strip()
            task_description = m.group(2).strip()
            cron = frequency_to_cron(frequency_str)
            if cron is None:
                continue

            entries.append({
                "frequency": frequency_str,
                "cron": cron,
                "task": task_description,
            })

    return entries


def register_schedules(db_path: Path, agent_slug: str, entries: list[dict]):
    """INSERT schedules into workspace.db, skipping duplicates."""
    if not db_path.exists():
        return 0

    conn = sqlite3.connect(str(db_path))
    cursor = conn.cursor()

    cursor.execute("""
        CREATE TABLE IF NOT EXISTS schedules (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            agent_slug TEXT NOT NULL,
            cron_expression TEXT NOT NULL,
            task_description TEXT NOT NULL,
            source TEXT DEFAULT 'heartbeat',
            enabled INTEGER DEFAULT 1,
            next_run_at TEXT,
            last_run_at TEXT,
            created_at TEXT DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
            UNIQUE(agent_slug, cron_expression, task_description)
        )
    """)

    inserted = 0
    now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    for entry in entries:
        try:
            cursor.execute(
                """INSERT OR IGNORE INTO schedules
                   (agent_slug, cron_expression, task_description, source, next_run_at)
                   VALUES (?, ?, ?, 'heartbeat', ?)""",
                (agent_slug, entry["cron"], entry["task"], now),
            )
            if cursor.rowcount > 0:
                inserted += 1
        except sqlite3.Error:
            continue

    conn.commit()
    conn.close()
    return inserted


def main():
    if len(sys.argv) < 4:
        print(
            "Usage: register-heartbeat-schedules.py <agent_slug> <heartbeat_path> <workspace_root>",
            file=sys.stderr,
        )
        sys.exit(1)

    agent_slug = sys.argv[1]
    heartbeat_path = Path(sys.argv[2])
    workspace_root = Path(sys.argv[3])
    db_path = workspace_root / "data" / "workspace.db"

    entries = parse_heartbeat(heartbeat_path)
    if not entries:
        print(f"No scheduled entries found in {heartbeat_path}")
        sys.exit(0)

    inserted = register_schedules(db_path, agent_slug, entries)
    print(f"Registered {inserted} schedule(s) for {agent_slug} ({len(entries)} parsed)")


if __name__ == "__main__":
    main()
