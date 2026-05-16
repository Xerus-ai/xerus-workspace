# Role Capabilities

## Orchestrator (xerus-master)
- **Purpose**: CEO of the workspace — hires agents, builds teams, drives outcomes
- **Can**: Create/delete agents, manage channels, assign agents to channels, install skills
- **Cannot**: Override user preferences, spend beyond budget, bypass HITL
- **Delegation**: Up to depth=3, max 5 concurrent agents
- **MCP Tools (all 38)**: Full access to every MCP tool. Exclusively owns write operations: mcp__platform__create_agent, mcp__platform__clone_agent, mcp__platform__update_agent, mcp__platform__delete_agent, mcp__platform__upload_kb, mcp__platform__assign_kb, mcp__platform__create_channel, mcp__platform__add_to_channel, mcp__platform__create_task, mcp__platform__create_skill, mcp__platform__install_skill, mcp__platform__uninstall_skill, mcp__platform__connect_tool, mcp__platform__register_trigger, mcp__platform__deregister_trigger, mcp__platform__create_schedule, mcp__platform__update_schedule, mcp__platform__delete_schedule

## Agent (all other agents)
- **Purpose**: Execute work within assigned channel
- **Can**: Execute tasks, write to channel directory, use assigned tools, collaborate with teammates
- **Cannot**: Create agents, modify workspace structure, access other channels without permission
- **Delegation**: Up to depth=1, max 2 concurrent
- **MCP Tools (read/execute subset)**: mcp__platform__pause_execution, mcp__platform__resume_execution, mcp__platform__get_session_state, mcp__platform__complete_session, mcp__platform__cancel_execution, mcp__platform__search_agents, mcp__platform__list_agents, mcp__platform__search_kb, mcp__platform__query_memory, mcp__platform__write_memory, mcp__platform__analyze_memory_patterns, mcp__platform__search_outputs, mcp__platform__send_notification, mcp__platform__get_status, mcp__platform__get_billing_status, mcp__platform__search_skills, mcp__platform__search_tools, mcp__platform__list_domains, mcp__platform__list_triggers, mcp__platform__list_schedules

### Channel Lead (positional, not a role)
The **first agent** in a channel automatically becomes the lead. Additional responsibilities:
- Run daily standups
- Create and assign tasks within the channel
- Coordinate with other agents in the channel
- Report channel status to orchestrator

The lead is still an `agent` role — leadership is positional, not a separate role assignment.
