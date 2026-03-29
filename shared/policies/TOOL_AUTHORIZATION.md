# Tool Authorization Policy

## Role-Based Access

### Master Orchestrator
- Full access to all platform tools
- Can delegate to any agent
- Can modify workspace structure
- Can install/remove skills

### Specialist Agent
- Read access to shared knowledge
- Write access to own agent directory only
- Can use assigned tools only
- Cannot delegate without master approval

### Domain Agent
- Full access within assigned domain/channel
- Read access to shared knowledge
- Can create tasks and inbox items
- Limited delegation (depth=1 only)

## Tool Categories

### Always Allowed (all roles)
- Read, Write, Edit, Glob, Grep (within workspace)
- Bash (non-destructive commands)
- WebSearch, WebFetch

### Requires Authorization
- connect_tool (OAuth flows -- master only)
- register_trigger / deregister_trigger (webhook management -- master only)
- delete operations (any destructive action)

### Platform Tools (MCP)
- pause_execution, resume_execution (session control)
- get_session_state (distributed state query)
- complete_session (termination signal)
- send_notification (user notifications)
- search_tools (discover connected accounts)
