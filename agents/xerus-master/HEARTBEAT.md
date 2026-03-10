# Heartbeat

## Scheduled

| Frequency | Task |
|-----------|------|
| Every 15 min | Check blocked tasks, idle agents, credit burn rate |
| Every hour | Summarize per-channel activity, flag progress gaps |
| Daily 9:00 AM | Morning standup per channel, flag blockers |
| Daily 6:00 PM | Deliverables summary, pending decisions for human |
| Weekly Monday | Cross-project summary, agent performance, credit projection |
| Weekly Friday | Data ecosystem health: query research_reports count, entity coverage, stale metrics, orphaned scratch files |

## Events

- New agent bootstrapped -> verify data-steward skill in their Module CLAUDE.md
- Domain extension SQL added to data/extensions/ -> run sqlite3 to load it
