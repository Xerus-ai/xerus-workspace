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
- connect_tool (OAuth flows)
- register_trigger / deregister_trigger (webhook management)
- create_agent / delete_agent
- install_skill / uninstall_skill

### Requires User Approval
- delete operations (any destructive action)
- spending above budget threshold

### Platform Tools (MCP) — All 38 Tools

**All Roles (Orchestrator + Agent):**
- **Session Control**: pause_execution, resume_execution, get_session_state, complete_session, cancel_execution
- **Knowledge Base**: search_kb
- **Memory**: query_memory, write_memory, analyze_memory_patterns
- **Outputs**: search_outputs
- **Communication**: send_notification
- **Status**: get_status, get_billing_status
- **Search**: search_agents, list_agents, search_skills, search_tools, list_domains, list_triggers, list_schedules

**Orchestrator Only:**
- **Agent Management**: create_agent, clone_agent, update_agent, delete_agent
- **Knowledge Base (write)**: upload_kb, assign_kb
- **Channels & Tasks**: create_channel, add_to_channel, create_task
- **Skills (write)**: create_skill, install_skill, uninstall_skill
- **Integrations**: connect_tool
- **Triggers**: register_trigger, deregister_trigger
- **Scheduling**: create_schedule, update_schedule, delete_schedule

**Requires User Approval:**
- delete_agent (destructive)
- deregister_trigger (removes automation)
- delete_schedule (removes automation)
- Any spending above budget threshold (get_billing_status to check first)
