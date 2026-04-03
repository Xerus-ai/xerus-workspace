# /handoff - Agent Work Handoff

Hand off work to another agent in your channel.

## Usage

```
/handoff {target-agent} [--context "what to hand off"]
```

## Protocol

1. **Validate Target**
   - Check target agent exists in the same channel
   - Check target agent is not paused

2. **Capture Context**
   - Current task state (from .task-context.md)
   - Recent work (from working.md)
   - Any deliverables in progress

3. **Write Handoff Record**
   - Write to `.channel/state/handoffs/{timestamp}-{from}-to-{to}.yaml`
   - Include: context, deliverables, tasks, notes

4. **Notify Target**
   - Write coordination message to channel output/posts.jsonl
   - Update target's inbox with handoff file reference

5. **Update Own State**
   - Update STATUS.md with handoff note
   - Clear or reassign current tasks

## Handoff Record Format

```yaml
# .channel/state/handoffs/2026-03-29T14-30-00-carla-to-vince.yaml
from: curator-carla
to: viral-vince
timestamp: 2026-03-29T14:30:00Z
context: |
  Completed morning trend research. Found 3 high-urgency trends.

deliverables:
  - path: output/deliverables/trends-2026-03-29.md
    status: complete
    notes: "Ready for content ideation"

in_progress_tasks:
  - id: task-123
    title: "Additional competitor analysis"
    status: paused
    notes: "Hand off to Vince to continue"

handoff_notes: |
  The Manus trend is especially hot right now. Prioritize that first.
```

## Cross-Channel Handoffs

For handoffs to another channel:
1. Write coordination message to target channel's output/posts.jsonl
2. Include full context in the message body
3. Update own STATUS.md with cross-channel handoff note

## Example

```
/handoff viral-vince --context "Morning research complete, 3 trends ready"
```
