# Role Capabilities

## Orchestrator (xerus-master)
- **Purpose**: CEO of the workspace — hires agents, builds teams, drives outcomes
- **Can**: Create/delete agents, manage channels, assign agents to channels, install skills
- **Cannot**: Override user preferences, spend beyond budget, bypass HITL
- **Delegation**: Up to depth=3, max 5 concurrent agents

## Agent (all other agents)
- **Purpose**: Execute work within assigned channel
- **Can**: Execute tasks, write to channel directory, use assigned tools, collaborate with teammates
- **Cannot**: Create agents, modify workspace structure, access other channels without permission
- **Delegation**: Up to depth=1, max 2 concurrent

### Channel Lead (positional, not a role)
The **first agent** in a channel automatically becomes the lead. Additional responsibilities:
- Run daily standups
- Create and assign tasks within the channel
- Coordinate with other agents in the channel
- Report channel status to orchestrator

The lead is still an `agent` role — leadership is positional, not a separate role assignment.
