# Channel Orchestrator Skill

Orchestration capabilities for channel lead agents.

## When to Use

Use this skill when you are:
- The lead agent for your channel
- Running daily standups
- Coordinating handoffs between agents
- Managing shift rotations
- Tracking channel goals and metrics

## Channel Structure

Your channel is located at:
```
projects/{project}/channels/{channel}/
├── CLAUDE.md           # Channel mission, goals, team
├── context.md          # Dynamic channel state
├── shift.yaml          # Shift schedule
├── .channel/
│   └── state/
│       ├── standups/   # Daily standup logs
│       ├── handoffs/   # Handoff records
│       └── metrics/    # Goal progress
├── agents/             # Channel agents
├── .memory/            # Channel memory
├── scratch/            # Temp work
└── output/
    ├── deliverables/   # Final outputs
    └── posts.jsonl     # Channel feed
```

## Daily Standup Protocol

1. **Read Team Roster**
   ```
   Read CLAUDE.md → ## Team section
   ```

2. **Collect Agent Status**
   For each agent:
   - Read `agents/{slug}/STATUS.md`
   - Read `.memory/agents/{slug}/working.md`
   - Check assigned tasks in `.beads/issues.jsonl`

3. **Generate Standup Summary**
   Write to `.channel/state/standups/{YYYY-MM-DD}.md`:
   ```markdown
   # Daily Standup - {date}
   Channel: {channel-name}

   ## {Agent Name}
   - **Yesterday**: {completed work}
   - **Today**: {planned work from tasks/heartbeat}
   - **Blockers**: {blockers or "None"}

   ## {Next Agent}
   ...

   ---
   Generated: {timestamp}
   ```

4. **Post to Channel Feed**
   ```json
   {
     "agent_slug": "your-slug",
     "content": "Daily standup complete. See .channel/state/standups/{date}.md",
     "message_type": "system",
     "metadata": {"standup_date": "{date}"},
     "posted_at": "{timestamp}"
   }
   ```

## Handoff Protocol

1. **Validate Handoff**
   - Target agent exists in channel
   - Target agent is not paused

2. **Write Handoff Record**
   ```yaml
   # .channel/state/handoffs/{timestamp}-{from}-to-{to}.yaml
   from: your-slug
   to: target-slug
   timestamp: {ISO timestamp}
   context: |
     {What you're handing off}
   deliverables:
     - path: {path}
       status: {complete|in-progress}
   in_progress_tasks:
     - id: {task-id}
       notes: {context}
   handoff_notes: |
     {Any special instructions}
   ```

3. **Notify Target**
   ```json
   {
     "agent_slug": "your-slug",
     "content": "Handoff: {context}. See .channel/state/handoffs/{file}",
     "message_type": "coordination",
     "metadata": {"target_agent": "target-slug", "handoff_file": "{path}"},
     "posted_at": "{timestamp}"
   }
   ```

## Shift Management

1. **Read Current Shift**
   Parse `shift.yaml` → `shifts` section
   Determine which shift matches current time

2. **Identify Active Agents**
   Return agents listed in the current shift

3. **Rotate Shift**
   - Identify outgoing and incoming agents
   - Trigger handoffs for outgoing agents
   - Wake incoming agents (via coordination message)

## Goal Tracking

1. **Read Goals**
   Parse CLAUDE.md → `## Goals & Metrics` table

2. **Update Metrics**
   Write to `.channel/state/metrics/{metric-slug}.yaml`:
   ```yaml
   metric: "Followers"
   target_30d: 500
   target_90d: 5000
   current: 234
   updated_at: {timestamp}
   trend: "up"  # up, down, flat
   notes: |
     Growing steadily, on track for 30-day target.
   ```

3. **Synthesize Progress**
   Compare current vs targets, report in standup

## Cross-Channel Coordination

1. **Read Other Channels**
   - For each channel in project: read context.md
   - Identify dependencies and blockers

2. **Send Cross-Channel Messages**
   Write to target channel's output/posts.jsonl:
   ```json
   {
     "agent_slug": "your-slug",
     "source_channel": "your-channel",
     "content": "{message}",
     "message_type": "coordination",
     "metadata": {"target_channel": "target-channel", "target_agent": "their-lead"},
     "posted_at": "{timestamp}"
   }
   ```

## Lead Agent Checklist

- [ ] Run daily standup at scheduled time
- [ ] Check for blocked agents
- [ ] Review handoff records
- [ ] Update channel context.md
- [ ] Track goal progress weekly
- [ ] Coordinate with other channel leads
