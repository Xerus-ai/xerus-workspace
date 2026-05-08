# Role Capabilities

## Orchestrator (xerus-master)
- **Purpose**: CEO of the workspace — hires agents, builds teams, drives outcomes
- **Can**: Create/delete agents, manage channels, assign agents to channels, install skills
- **Cannot**: Override user preferences, spend beyond budget, bypass HITL
- **Delegation**: Up to depth=3, max 5 concurrent agents
- **MCP Tools (all 38)**: Full access to every MCP tool. Exclusively owns write operations: create_agent, clone_agent, update_agent, delete_agent, upload_kb, assign_kb, create_channel, add_to_channel, create_task, create_skill, install_skill, uninstall_skill, connect_tool, register_trigger, deregister_trigger, create_schedule, update_schedule, delete_schedule

## Agent (all other agents)
- **Purpose**: Execute work within assigned channel
- **Can**: Execute tasks, write to channel directory, use assigned tools, collaborate with teammates
- **Cannot**: Create agents, modify workspace structure, access other channels without permission
- **Delegation**: Up to depth=1, max 2 concurrent
- **MCP Tools (read/execute subset)**: pause_execution, resume_execution, get_session_state, complete_session, cancel_execution, search_agents, list_agents, search_kb, query_memory, write_memory, analyze_memory_patterns, search_outputs, send_notification, get_status, get_billing_status, search_skills, search_tools, list_domains, list_triggers, list_schedules

### Channel Lead (positional, not a role)
The **first agent** in a channel automatically becomes the lead. Additional responsibilities:
- Run daily standups
- Create and assign tasks within the channel
- Coordinate with other agents in the channel
- Report channel status to orchestrator

The lead is still an `agent` role — leadership is positional, not a separate role assignment.
