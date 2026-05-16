# Tool Authorization Policy

## Role-Based Access

### Orchestrator (xerus-master)
- Full access to all platform tools
- Can delegate to any agent
- Can modify workspace structure
- Can install/remove skills
- Can create/delete agents

### Agent (all other agents)
- Read access to shared knowledge
- Write access to own channel directory
- Can use assigned tools only
- Can create tasks and inbox items
- Limited delegation (depth=1 only)

## Tool Categories

### Always Allowed (all roles)
- Read, Write, Edit, Glob, Grep (within workspace)
- Bash (non-destructive commands)
- WebSearch, WebFetch

### Orchestrator Only
- mcp__platform__connect_tool (OAuth flows)
- mcp__platform__register_trigger / mcp__platform__deregister_trigger (webhook management)
- mcp__platform__create_agent / mcp__platform__delete_agent
- mcp__platform__install_skill / mcp__platform__uninstall_skill

### Requires User Approval
- delete operations (any destructive action)
- spending above budget threshold

### Platform Tools (MCP) — All 38 Tools

**All Roles (Orchestrator + Agent):**
- **Session Control**: mcp__platform__pause_execution, mcp__platform__resume_execution, mcp__platform__get_session_state, mcp__platform__complete_session, mcp__platform__cancel_execution
- **Knowledge Base**: mcp__platform__search_kb
- **Memory**: mcp__platform__query_memory, mcp__platform__write_memory, mcp__platform__analyze_memory_patterns
- **Outputs**: mcp__platform__search_outputs
- **Communication**: mcp__platform__send_notification
- **Status**: mcp__platform__get_status, mcp__platform__get_billing_status
- **Search**: mcp__platform__search_agents, mcp__platform__list_agents, mcp__platform__search_skills, mcp__platform__search_tools, mcp__platform__list_domains, mcp__platform__list_triggers, mcp__platform__list_schedules

**Orchestrator Only:**
- **Agent Management**: mcp__platform__create_agent, mcp__platform__clone_agent, mcp__platform__update_agent, mcp__platform__delete_agent
- **Knowledge Base (write)**: mcp__platform__upload_kb, mcp__platform__assign_kb
- **Channels & Tasks**: mcp__platform__create_channel, mcp__platform__add_to_channel, mcp__platform__create_task
- **Skills (write)**: mcp__platform__create_skill, mcp__platform__install_skill, mcp__platform__uninstall_skill
- **Integrations**: mcp__platform__connect_tool
- **Triggers**: mcp__platform__register_trigger, mcp__platform__deregister_trigger
- **Scheduling**: mcp__platform__create_schedule, mcp__platform__update_schedule, mcp__platform__delete_schedule

**Requires User Approval:**
- mcp__platform__delete_agent (destructive)
- mcp__platform__deregister_trigger (removes automation)
- mcp__platform__delete_schedule (removes automation)
- Any spending above budget threshold (mcp__platform__get_billing_status to check first)
