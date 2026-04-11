# /standup - Daily Channel Standup

Run a daily standup for a channel, collecting status from all agents.

## Usage

```
/standup [channel-path]
```

If no channel path provided, runs standup for the current agent's channel.

## Protocol

1. **Read Channel Config**
   - Read channel's CLAUDE.md for team roster
   - Read channel's shift.yaml for schedule

2. **Collect Agent Status**
   For each agent in the channel:
   - Read `agents/{slug}/STATUS.md` for current state
   - Read `.memory/agents/{slug}/working.md` for recent work
   - Check `.beads/issues.jsonl` for assigned tasks

3. **Generate Standup Report**
   For each agent, summarize:
   - **Yesterday**: What was completed
   - **Today**: What's planned (from tasks or HEARTBEAT.md)
   - **Blockers**: Any dependencies or issues

4. **Write Output**
   - Write standup to `.channel/state/standups/{YYYY-MM-DD}.md`
   - Post summary to `output/posts.jsonl` with `message_type: "system"`

## Output Format

```markdown
# Daily Standup - {date}
Channel: {channel-name}

## {Agent Name}
- **Yesterday**: {completed work}
- **Today**: {planned work}
- **Blockers**: {blockers or "None"}

## {Next Agent}
...

---
Generated: {timestamp}
Participants: {list of agents}
```

## Cross-Channel Standups

For workspace-wide standup (growth channel responsibility):
1. Read all channel standup files from `.channel/state/standups/`
2. Synthesize into the growth channel's `output/posts.jsonl` with `message_type: "system"`

## Example

```
/standup projects/xerus-launch/channels/twitter
```

Produces: `projects/xerus-launch/channels/twitter/.channel/state/standups/2026-03-29.md`
