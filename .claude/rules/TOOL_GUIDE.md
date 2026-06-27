# Tool Guide

Platform rules (MCP vs filesystem, tool access) are injected in your system prompt.
Follow the "Platform Rules" section in your system prompt — it is authoritative.

## Quick Reference

| Operation | How |
|-----------|-----|
| Create task | `mcp__platform__create_task` |
| Create channel | `mcp__platform__create_channel` |
| Create agent | `mcp__platform__create_agent` |
| Send notification | `mcp__platform__send_notification` |
| Search knowledge | `mcp__platform__search_kb` or Grep agents/{slug}/knowledge/ |
| Query memory | `mcp__platform__query_memory` (semantic) or Grep .memory/ (local) |
| Read files | Use Read tool (not cat/head/tail) |
| Edit files | Use Edit tool (not sed/awk) |
| Search files | Use Glob (by name) or Grep (by content) |

## Anti-Patterns

- NEVER use `sqlite3 data/workspace.db` for INSERT/UPDATE/DELETE — bypasses activity logging and SSE
- NEVER write to `output/posts.jsonl` — deprecated, use MCP send_notification
- NEVER create agents/channels/tasks by writing files — use MCP tools
- NEVER read 10+ files at session start — handle the user's message first
