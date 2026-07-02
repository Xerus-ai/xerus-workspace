# Xerus Workspace

You are an agent in the Xerus AI workforce. Your identity, role, and platform rules are injected in your system prompt — follow them.

## Goal Hierarchy

```
drive/company.md                        Company vision, mission, values, north star
  └─ projects/{domain}/CLAUDE.md        Project mission, OKRs, channel list
       └─ channels/{channel}/CLAUDE.md  Channel mission, goals, metrics, team, rules
            └─ agents/{slug}/CLAUDE.md  Agent skills, knowledge, colleagues
```

Every decision should trace back to this hierarchy.

## Session Start

- **Handle the user's message first.** Do not read files upfront unless the request requires them.
- Read files on demand, not as a startup checklist.
- Save progress to `.memory/agents/{your-slug}/working.md` before session ends.
- At 75%+ context usage: save all progress to working.md immediately.

## Workspace Layout

```
drive/                                  Company-wide documents
projects/{domain}/channels/{channel}/   Your working directory
agents/{your-slug}/                     Your identity, config, knowledge
.memory/agents/{your-slug}/             Your working memory (read/write)
.claude/skills/                         Installed skills (auto-discovered)
data/company.db                         Business data (research, prospects — SQLite)
data/workspace.db                       Operational data (DO NOT write directly — use MCP tools)
marketplace/                            Read-only skill/agent catalog
scratch/                                Disposable work files
output/deliverables/                    Final deliverables (persistent) — see "Deliverables" below
```

## Deliverables

Save finished work where it will surface in the Drive UI:

- **Preferred:** `projects/{domain}/channels/{channel}/output/deliverables/` — keeps deliverables organized per channel and attributed to your team. Shown in Drive under the project (and channel) display name.
- **Also works:** top-level `output/deliverables/` — for non-channel work. Shown in Drive under a `Deliverables` folder.

Both locations are persistent and are surfaced by the Drive readers; prefer the per-channel path when you are working inside a channel.

## Data Rules

- `company.db` — business data agents produce (research, prospects, metrics). Agents CAN read/write via sqlite3.
- `workspace.db` — operational state (agents, channels, tasks, inbox). NEVER write directly. Use MCP tools only.

## Tool Usage

Use Claude Code's built-in tools (Read, Edit, Write, Glob, Grep) for file operations.
Use MCP platform tools (`mcp__platform__*`) for all UI-visible mutations.
See "Platform Rules" in your system prompt for the full list.

## Skills

Skills at `.claude/skills/` are auto-discovered. Use skill frameworks directly.

## Browser

Shared Chromium via `agent-browser` skill. Prefer browser over installing packages.
