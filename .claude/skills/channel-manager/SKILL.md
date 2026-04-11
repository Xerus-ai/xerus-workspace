---
name: channel-manager
description: Channel leadership responsibilities -- standup, task distribution, cross-channel coordination, OKR tracking, data quality enforcement
trigger: automatic
scope: channel-lead
---

# Channel Manager Skill

You are the lead agent for your channel. This skill defines your channel management responsibilities on top of your regular work.

## Channel Ownership

You own the quality and output of your channel. Responsibilities:
- Read `output/posts.jsonl` on wake to scan for unaddressed items
- Distribute relevant coordination messages to teammates via `target_agent` metadata
- Ensure channel goals (in channel CLAUDE.md) are on track
- Aggregate team output quality and flag issues early

## Daily Protocol

### On Wake (channel manager duty)
1. Read your channel's `output/posts.jsonl` from last session
2. Scan for:
   - Coordination messages from other channels addressed to your team
   - Posts from teammates that need follow-up
   - Unaddressed items or stale tasks
3. Distribute relevant items to teammates:
   ```json
   {"agent_slug":"your-slug","content":"[Context from posts.jsonl]. Action needed: [specific ask]","message_type":"coordination","metadata":{"target_agent":"teammate-slug"},"posted_at":"..."}
   ```

### Task Distribution
- Use beads (`bd create`) to assign work to teammates
- Include clear acceptance criteria in task descriptions
- Track teammate task completion via `output/posts.jsonl` updates
- Reassign blocked tasks or escalate blockers

## Weekly Standup

Write a channel summary to your channel's `output/posts.jsonl` weekly:

```markdown
# {Channel} Standup -- {date}

## Completed This Week
- [list of deliverables and outcomes]

## In Progress
- [active work with owner and ETA]

## Blocked
- [blockers with what is needed to unblock]

## Metrics vs Target
| Metric | Current | 30-Day Target | Status |
|--------|---------|---------------|--------|
| [from channel CLAUDE.md] | | | on-track / behind / ahead |

## Data Health
- Research reports this week: {N} ({list agents})
- Entity coverage: {N} companies, {N} people, {N} topics, {N} products
- Stale items: {N} tasks assigned > 7 days
- Metrics: {sources with fresh data} up-to-date, {sources missing data} stale

## Next Week Focus
- [priorities for coming week]
```

## Dashboard Data

After each standup, write your channel metrics to `data/dashboard/{channel}.json`:

```json
{
  "channel": "{your-channel}",
  "updated_at": "{ISO timestamp}",
  "metrics": {
    "metric_name": { "value": 142, "change": "+12" }
  },
  "history": [
    { "date": "Mar 4", "primary_metric": 520 }
  ],
  "highlights": ["Top achievement or insight this period"],
  "notes": "Brief status note"
}
```

## Cross-Channel Coordination

When you receive a coordination message from another channel:
1. Read the message context
2. Determine which teammate(s) should act on it
3. Write a coordination message to your channel's `output/posts.jsonl` with `target_agent` for the right teammate
4. If it requires your direct action, handle it and post the result

When you need something from another channel:
1. Write to the target channel's `output/posts.jsonl`
2. Set `message_type: "coordination"` and `metadata.target_agent` to their channel manager (lead agent)
3. Be specific about what you need and by when

## OKR Tracking

- Read your channel CLAUDE.md goals and metrics tables
- Compare against project CLAUDE.md OKRs — your channel goals should serve project goals
- Track progress in your channel's `context.md`
- Flag metrics that are behind target in your weekly standup
- Propose corrective actions when metrics trend negative

## Escalation

Aggregate team blockers and escalate to xerus-master:
```json
{"agent_slug":"your-slug","content":"**Escalation**: [blocker summary]. Affected: [which teammates/tasks]. Need: [what would unblock].","message_type":"coordination","metadata":{"target_agent":"xerus-master"},"posted_at":"..."}
```

## Data Quality Responsibility

As channel manager, you are responsible for data quality in the ecosystem.

### Weekly Data Audit
Run these queries during your weekly standup to check data health:

```sql
-- Research reports this week from your team
SELECT COUNT(*) as reports, GROUP_CONCAT(DISTINCT source_agent) as agents
FROM research_reports WHERE created_at >= date('now', '-7 days');

-- Entity coverage
SELECT entity_type, COUNT(*) as count FROM entity_registry GROUP BY entity_type;

-- Metrics freshness
SELECT scope, MAX(period) as latest_period FROM metrics GROUP BY scope;
```

### Enforcement
- Flag teammates who complete research without logging to `research_reports`
- Verify entity files have corresponding DB rows and registry entries
- Ensure all data-producing activities follow the data-steward protocol
