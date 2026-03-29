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
- install_skill / remove_skill

### Requires User Approval
- delete operations (any destructive action)
- spending above budget threshold

### Platform Tools (MCP)
- pause_execution, resume_execution (session control)
- get_session_state (distributed state query)
- complete_session (termination signal)
- send_notification (user notifications)
- search_tools (discover connected accounts)
