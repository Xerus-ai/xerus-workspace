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
    "every 15 min": "*/15 * * * *",
    "every hour": "0 * * * *",
    "weekly monday 9:00 am": "0 9 * * 1",
    "weekly monday": "0 9 * * 1",
    "weekly friday 5:00 pm": "0 17 * * 5",
    "weekly friday": "0 17 * * 5",
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
    """Parse HEARTBEAT.md and extract scheduled entries.

    Supports two formats:
    - Bullet: ``- **Every 15 min**: task description``
    - Pipe-table: ``| Every 15 min | task description |``
    """
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

            frequency_str = None
            task_description = None

            # Bullet format: - **Frequency**: task
            m = re.match(r"-\s+\*\*(.+?)\*\*:\s*(.+)", stripped)
            if m:
                frequency_str = m.group(1).strip()
                task_description = m.group(2).strip()

            # Pipe-table format: | Frequency | task |
            if not m:
                m = re.match(r"\|\s*(.+?)\s*\|\s*(.+?)\s*\|", stripped)
                if m:
                    freq_candidate = m.group(1).strip()
                    task_candidate = m.group(2).strip()
                    # Skip header rows (containing dashes or header labels)
                    if freq_candidate.startswith("-") or freq_candidate.lower() == "frequency":
                        continue
                    frequency_str = freq_candidate
                    task_description = task_candidate

            if not frequency_str or not task_description:
                continue

            cron = frequency_to_cron(frequency_str)
            if cron is None:
                continue

            entries.append({
                "frequency": frequency_str,
                "cron": cron,
                "task": task_description,
            })

    return entries


CRON_TO_RRULE = {
    "0 * * * *":     "FREQ=HOURLY;BYHOUR=0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23",
    "*/15 * * * *":  "FREQ=MINUTELY;INTERVAL=15",
    "*/30 * * * *":  "FREQ=MINUTELY;INTERVAL=30",
}


def cron_to_rrule(cron: str) -> str:
    """Convert a cron expression to an RRULE string."""
    if cron in CRON_TO_RRULE:
        return CRON_TO_RRULE[cron]

    parts = cron.split()
    if len(parts) != 5:
        return f"FREQ=DAILY"

    minute, hour, _dom, _month, dow = parts

    dow_map = {"0": "SU", "1": "MO", "2": "TU", "3": "WE", "4": "TH", "5": "FR", "6": "SA"}

    if dow != "*":
        rrule = f"FREQ=WEEKLY;BYDAY={dow_map.get(dow, 'MO')};BYHOUR={hour};BYMINUTE={minute}"
    else:
        rrule = f"FREQ=DAILY;BYHOUR={hour};BYMINUTE={minute}"
    return rrule


def register_schedules(db_path: Path, agent_slug: str, entries: list[dict]):
    """INSERT schedules into the schedules table (read by the scheduler daemon)."""
    if not db_path.exists():
        return 0

    conn = sqlite3.connect(str(db_path))
    cursor = conn.cursor()

    inserted = 0
    now_epoch = int(datetime.now(timezone.utc).timestamp())
    for entry in entries:
        schedule_id = f"hb-{agent_slug}-{entry['cron'].replace(' ', '-').replace('*', 'x').replace('/', 'd')}"
        schedule_name = f"heartbeat:{agent_slug}:{entry['frequency']}"
        rrule = cron_to_rrule(entry["cron"])
        try:
            cursor.execute(
                """INSERT OR IGNORE INTO schedules
                   (id, agent_slug, name, prompt, rrule, status, next_run_at, created_at, updated_at)
                   VALUES (?, ?, ?, ?, ?, 'active', ?, ?, ?)""",
                (schedule_id, agent_slug, schedule_name, entry["task"],
                 rrule, now_epoch, now_epoch, now_epoch),
            )
            if cursor.rowcount > 0:
                inserted += 1
        except sqlite3.Error as e:
            print(f"WARN: Failed to insert schedule for {agent_slug}: {e}", file=sys.stderr)
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
