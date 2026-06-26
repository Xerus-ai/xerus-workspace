# Xerus Workspace

You are an agent in the Xerus AI workforce. Follow these standard operating procedures.

## Goal Hierarchy

```
drive/company.md                        Company vision, mission, values, north star
  └─ projects/{domain}/CLAUDE.md        Project mission, OKRs, channel list
       └─ channels/{channel}/CLAUDE.md  Channel mission, goals, metrics, team, rules
            └─ agents/{slug}/CLAUDE.md  Agent skills, knowledge, colleagues
```

Every decision should trace back to this hierarchy. Channel goals serve project OKRs. Project OKRs serve company goals. If your work doesn't connect to a goal, question whether it should be done.

## Tool Naming Convention

Platform MCP tools use the format: `mcp__platform__<tool_name>`
Example: `mcp__platform__list_agents`, `mcp__platform__query_memory`

The full list of 38 tools is documented in `.claude/rules/TOOL_GUIDE.md`.

## Workspace Layout

```
drive/company.md                        Company vision, mission, values, current goals
drive/                                  Company-wide documents (company.md = source of truth for vision/goals)
projects/{domain}/channels/{channel}/   Your working directory (channel = team)
projects/{domain}/CLAUDE.md             Department strategy, OKRs
agents/{your-slug}/                     Your definition, config, inbox, knowledge
agents/{your-slug}/SOUL.md              Your personality, values, communication style
agents/{your-slug}/STATUS.md            Current mood, energy, active tasks
agents/{your-slug}/USER.md              Learned user preferences and patterns
agents/{your-slug}/RELATIONSHIPS.md     Teammate rapport and collaboration notes
agents/{your-slug}/BOOTSTRAP.md         First-session onboarding checklist
.memory/agents/{your-slug}/working.md   Your active state (read/write, memory)
.memory/agents/{your-slug}/expertise.md Your learned expertise (read/write, memory)
.memory/                                Hierarchical memory (git-tracked)
.claude/skills/                         Installed skills (auto-discovered)
.claude/rules/                          Workspace policies and access rules
.xerus/templates/                       Workspace templates and resources
data/activity.jsonl                     Execution log (who ran what, when)
data/dashboard/                         Dashboard data and metrics
data/company.db                         Business data (research, prospects, metrics — SQLite)
data/workspace.db                       Operational data (agents, channels, execution, tasks, inbox — SQLite)
marketplace/                            Read-only skill/agent catalog
```

## Session Start

Your OPERATING.md (injected in your system prompt) defines your session-start protocol. Follow it — not this section.

General rules:
- **Handle the user's message first.** Do not read files upfront unless the user's request requires them.
- Read files **on demand**, not as a startup checklist. If you need company context, read company.md. If you don't, skip it.
- Save progress to `.memory/agents/{your-slug}/working.md` before session ends.
- At 75%+ context usage: save all progress to working.md immediately.

## Communication

All communication goes through channel `output/posts.jsonl`. Each line is a JSON object:

```json
{"agent_slug":"your-slug","content":"Your message here","message_type":"post","metadata":{},"posted_at":"2026-03-07T10:30:00Z"}
```

### Message Types

| Type | Use | Example |
|------|-----|---------|
| `post` | Standard update, deliverable announcement | `"message_type": "post"` |
| `coordination` | Agent-to-agent message | `"message_type": "coordination"` + `"metadata": {"target_agent": "their-slug"}` |
| `system` | Status change, completion event | `"message_type": "system"` |

### Routing

- **Same team**: Channel manager reads `output/posts.jsonl` and distributes via coordination messages with `target_agent`
- **Cross team**: Write to the target channel's `output/posts.jsonl` with `message_type: "coordination"` and `metadata.target_agent` set to their channel manager (lead agent)
- **Escalation**: Write to your channel's `output/posts.jsonl` with `message_type: "post"` and `metadata.requires_approval: true`
- **Human**: Write to your channel's `output/posts.jsonl` with `@human` in content
- **Updates**: Write to your channel's `output/posts.jsonl` with `message_type: "post"`

### Coordination Message Contract

`coordination` messages MUST include `target_agent` (string) or `target_agents` (string[]) in metadata. The backend channel-watcher delivers these directly to agent inboxes. `post` and `system` messages are for humans/frontend only and are not delivered to inboxes.

### Examples

Standard post:
```json
{"agent_slug":"thread-theo","content":"**Draft thread ready.** See output/deliverables/thread-ai-workforce.md","message_type":"post","metadata":{},"posted_at":"2026-03-07T10:30:00Z"}
```

Coordination (agent-to-agent):
```json
{"agent_slug":"curator-carla","content":"Can you generate 3 ideas from the AI coding trend?","message_type":"coordination","metadata":{"target_agent":"viral-vince"},"posted_at":"2026-03-07T11:00:00Z"}
```

Escalation (needs human approval):
```json
{"agent_slug":"ad-alex","content":"**Budget increase request.** Google CPC dropped 20%, recommend reallocating $50 from LinkedIn.","message_type":"post","metadata":{"requires_approval":true},"posted_at":"2026-03-07T12:00:00Z"}
```

### Reading Messages

Check your channel's `output/posts.jsonl` for coordination messages where `metadata.target_agent` matches your slug. The backend also delivers @mentions to `agents/{your-slug}/inbox/` automatically — check on wake but do not write there yourself.

## Tool Usage

Use specialized tools instead of bash commands:
- Read files: Use Read (not cat/head/tail)
- Edit files: Use Edit (not sed/awk)
- Create files: Use Write (not echo/cat heredoc)
- Search by filename: Use Glob (not find/ls)
- Search file contents: Use Grep (not grep/rg)
- Run scripts, install packages: Use Bash

Call multiple tools in parallel when they are independent.

## Skills

Skills are installed at `.claude/skills/` and auto-discovered by the SDK. Use skill frameworks directly -- do not re-invent approaches your skills already cover.

## Browser

A shared Chromium browser is available via the `agent-browser` skill. Use it for Google Workspace, web automation, and previews. See `.claude/skills/agent-browser/SKILL.md` for commands and usage. Prefer the browser over installing packages (use Google Docs instead of pandoc, Google Sheets instead of xlsx).

## Output Conventions

- Intermediate work: `scratch/` (disposable between sessions)
- Final deliverables: `output/deliverables/` (persistent, visible in frontend)
- Channel posts: `output/posts.jsonl` (bridged to frontend as messages)
- Name files descriptively: `competitor-analysis-q1-2025.md` not `output.txt`
- Include metadata: date, source, confidence level where relevant

## Data Architecture

Three-layer storage model. All agents follow the `data-steward` skill protocol.

| Layer | Storage | Purpose |
|-------|---------|---------|
| **1. Google Sheets/Drive** | Google Workspace | Raw data, human-readable |
| **2a. company.db (SQLite)** | `data/company.db` | Business data: research, prospects, competitors, metrics |
| **2b. workspace.db (SQLite)** | `data/workspace.db` | Operational data: agents, channels, execution, tasks, inbox |
| **3. .memory/entities/** | Git-tracked files | Rich context, backlinked knowledge graph |

After ANY data-producing activity: persist to company.db, create entity files, notify downstream agents. See `.claude/skills/data-steward/SKILL.md` for tables, SQL, entity templates, and the full protocol.

**Database boundary**: `company.db` is for business data agents produce (research reports, prospects, metrics). `workspace.db` is for operational state (agents, domains, channels, channel_members, execution sessions, tasks, inbox). When creating channels or managing agents, always use `workspace.db`.
