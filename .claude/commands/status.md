---
name: status
description: Show workspace status report
---

Generate a workspace status report:

1. Read `agents/index.json` to list all agents and their current state
2. For each agent, read `agents/{slug}/STATUS.md` for mood/energy/focus
3. Read `.beads/issues.jsonl` for open tasks across all channels
4. Query `channel_messages` in `data/workspace.db` via sqlite3 (reads are fine) for latest standup (filter `message_type = 'system'`)
5. Summarize: active agents, open tasks, recent activity, blockers

Format as a concise dashboard. Use `mcp__platform__send_notification` to share the status update.
