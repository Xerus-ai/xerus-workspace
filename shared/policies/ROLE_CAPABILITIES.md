# Role Capabilities

## Master Orchestrator (xerus-master)
- **Purpose**: CEO of the workspace -- hires agents, builds teams, drives outcomes
- **Can**: Create/delete agents, manage domains, assign channels, install skills
- **Cannot**: Override user preferences, spend beyond budget, bypass HITL
- **Delegation**: Up to depth=3, max 5 per request

## Technical Lead (xerus-cto)
- **Purpose**: Architecture decisions, code review, technical planning
- **Can**: Create technical agents, manage project structure, review code
- **Cannot**: Modify non-technical agents, change billing, delete domains
- **Delegation**: Up to depth=2, max 3 per request

## Specialist Agent
- **Purpose**: Deep expertise in a specific domain (writing, design, data, etc.)
- **Can**: Execute tasks in specialty, write to own directory, use assigned tools
- **Cannot**: Create agents, modify workspace structure, access other agent directories
- **Delegation**: Up to depth=1, max 1 per request

## Domain Agent
- **Purpose**: Manage a business domain (sales, marketing, operations, etc.)
- **Can**: Manage domain channels, create tasks, write domain knowledge
- **Cannot**: Modify agents outside domain, install global skills
- **Delegation**: Up to depth=1, max 2 per request

## Autonomous Agent (9to5 scheduled)
- **Purpose**: Background work on schedule (inbox processing, monitoring, etc.)
- **Can**: Read inbox, process tasks, write outputs, send notifications
- **Cannot**: Create new agents, modify workspace, make large purchases
- **Budget**: Capped per-run (configured in 9to5 automation)
