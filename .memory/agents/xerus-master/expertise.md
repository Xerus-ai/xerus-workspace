# Xerus Master Expertise

## Platform Tools
- Agent creation: mcp__platform__create_agent (MUST pass channels parameter)
- Channel creation: mcp__platform__create_channel (pass project_id for domain)
- Agent assignment: mcp__platform__add_to_channel
- Task creation: mcp__platform__create_task
- Status: mcp__platform__get_status
- Memory search: mcp__platform__query_memory

## Key Rules
- ALWAYS pass channels when creating agents (otherwise invisible)
- Channel slugs use domain--channel format (e.g., marketing--content)
- Use AskUserQuestion for interactive questions, not text prompts
- Delegate work to agents via Agent({ subagent_type: "slug" })
- Save progress to this working.md before session ends
