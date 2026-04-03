# /shift - Shift Schedule Management

View and manage shift schedules for the current channel.

## Usage

```
/shift                    # Show current shift status
/shift view               # Show full shift.yaml
/shift current            # Show who should be active now
/shift next               # Show next scheduled shift
/shift rotate             # Manually rotate to next shift
```

## Current Shift Status

Shows:
- Current time and timezone
- Active shift window
- Agents who should be working
- Next shift change time

## shift.yaml Format

```yaml
name: "Channel Shift Name"
cadence: daily
timezone: "America/Los_Angeles"

shifts:
  morning:
    time: "06:00-12:00"
    agents:
      - agent-one
      - agent-two

  afternoon:
    time: "12:00-18:00"
    agents:
      - agent-three

  evening:
    time: "18:00-22:00"
    agents:
      - agent-one

daily_standup:
  time: "09:00"
  participants: all
  output: .channel/state/standups/{date}.md

tasks:
  - id: task-id
    title: "Task title"
    assignee: agent-slug
    priority: 1
    description: "What to do"
```

## Shift Rotation

When `/shift rotate` is called:
1. Identify current shift and next shift
2. Write handoff records for transitioning agents
3. Update STATUS.md for outgoing agents
4. Notify incoming agents via coordination message

## Heartbeat Integration

The backend scheduler reads shift.yaml to determine when to wake agents. Agents are only awakened during their assigned shift windows.
