---
name: status
description: Show workspace status report
---

Generate a workspace status report:

1. Read `agents/index.json` to list all agents and their current state
2. For each agent, read `agents/{slug}/STATUS.md` for mood/energy/focus
3. Read `.beads/issues.jsonl` for open tasks across all channels
4. Read `shared/standup/standup.md` for latest standup
5. Summarize: active agents, open tasks, recent activity, blockers

Format as a concise dashboard. Post to `output/posts.jsonl` as a status update.
