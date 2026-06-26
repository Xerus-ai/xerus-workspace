# Workspace Operations Guide

> This guide documents how to perform platform operations.
> For state mutations (create/delete agents, channels, tasks), ALWAYS use MCP platform tools.
> For read operations, use Claude Code's built-in tools (Read, Glob, Grep).
> NEVER use sqlite3 to create agents, channels, or tasks — it bypasses channel assignment and makes entities invisible.

## Quick Reference

| Operation | Tool | Notes |
|-----------|------|-------|
| **Create Agent** | `mcp__platform__create_agent` | MUST pass `channels` and `primary_channel` |
| **Clone Agent** | `mcp__platform__clone_agent` | |
| **Update Agent** | Read + Edit `agents/{slug}/config.json` | For config changes |
| **Delete Agent** | `mcp__platform__delete_agent` | |
| **Search Agents** | Glob + Read `agents/*/config.json` | |
| **List Agents** | Read `agents/index.json` | |
| **Create Channel** | `mcp__platform__create_channel` | Pass `project_id` for domain |
| **Add to Channel** | `mcp__platform__add_to_channel` | |
| **Create Task** | `mcp__platform__create_task` | |
| **Search KB** | Grep / Glob `agents/{slug}/knowledge/` | |
| **Upload to KB** | Write `agents/{slug}/knowledge/{filename}` | |
| **Create Skill** | `mcp__platform__create_skill` | |
| **Search Skills** | Glob + Grep `marketplace/skills/*/SKILL.md` | |
| **Write Memory** | Write `.memory/{scope}/{type}/{filename}.md` | |
| **Query Memory** | `mcp__platform__query_memory` | pgvector semantic search |
| **Get Status** | `mcp__platform__get_status` | |
| **List Domains** | `mcp__platform__list_domains` | |
| **Search Outputs** | Glob + Grep `output/` directories | |

---

## Agent Management

### Create an Agent

Use the MCP platform tool. It handles all scaffolding: config.json, agent.md, soul files, workspace.db registration, index.json, channel assignment.

**ALWAYS pass `channels` and `primary_channel`.** Without channels, the agent is invisible on the frontend.

```
mcp__platform__create_agent({
  name: "Research Rachel",
  description: "Market research specialist focused on competitive intelligence",
  system_prompt: "You are Research Rachel, a market research specialist...",
  model_id: "claude-sonnet",
  autonomy_level: "supervised",
  channels: ["marketing--research"],
  primary_channel: "marketing--research"
})
```

The tool returns the created agent with slug, status, and installed_at.

---

### Update an Agent

Read the current config, modify it, and write it back using Edit.

**Files:**
- `agents/{slug}/config.json` -- operational config
- `agents/{slug}/agent.md` -- system prompt (if updating personality/goals)

**Example -- change model and autonomy level:**

```
# Read current config
Read agents/research-rachel/config.json

# Edit the specific fields
Edit agents/research-rachel/config.json
  old_string: '"model": "claude-sonnet-4.5"'
  new_string: '"model": "claude-opus-4"'

Edit agents/research-rachel/config.json
  old_string: '"autonomy_level": "supervised"'
  new_string: '"autonomy_level": "autonomous"'
```

Also update the database record to stay in sync:

```bash
sqlite3 data/workspace.db "UPDATE agents SET autonomy_level = 'autonomous',
  config = json_set(config, '$.model', 'claude-opus-4'),
  updated_at = strftime('%Y-%m-%dT%H:%M:%SZ', 'now')
  WHERE slug = 'research-rachel';"
```

---

### Search Agents

Use Glob to find all agent configs, then Grep to filter by criteria.

**Files:** `agents/*/config.json`

**Example -- find agents with "research" in their role:**

```
# Find all agent config files
Glob pattern: "agents/*/config.json"

# Search for agents by role
Grep pattern: '"role":\s*"research"'
     path: agents/
     glob: "*/config.json"
     output_mode: content
```

**Example -- find agents with a specific tool:**

```
Grep pattern: '"firecrawl"'
     path: agents/
     glob: "*/config.json"
     output_mode: content
```

**Example -- find agents in the marketplace:**

```
Grep pattern: '"role":\s*"creative"'
     path: marketplace/agents/
     glob: "**/config.json"
     output_mode: content
```

---

### Clone an Agent

Use the MCP platform tool:

```
mcp__platform__clone_agent({
  source_agent_id: "research-rachel",
  new_name: "Research Rachel V2",
  new_slug: "research-rachel-v2"
})
```

---

### Delete an Agent

Use the MCP platform tool:

```
mcp__platform__delete_agent({
  agent_id: "research-rachel"
})
```

---

### List Agents

Enumerate all installed agents using Glob, then read each config for details.

**Files:** `agents/*/config.json`

**Example:**

```
# List all agent config files
Glob pattern: "agents/*/config.json"

# For a summary, also read the central index
Read agents/index.json
```

The `agents/index.json` file contains a quick-reference map:

```json
{
  "agents": {
    "xerus-master": {
      "name": "Xerus",
      "role": "Master Orchestrator",
      "is_master": true,
      "channel": null
    }
  }
}
```

For database-level listing with status:

```bash
sqlite3 data/workspace.db "SELECT slug, name, status, autonomy_level FROM agents ORDER BY slug;"
```

---

## Knowledge Base Management

### Search Knowledge Base

Search an agent's knowledge base files by content or filename.

**Files:** `agents/{slug}/knowledge/`

**Example -- search by content:**

```
Grep pattern: "competitive analysis"
     path: agents/research-rachel/knowledge/
     output_mode: content
```

**Example -- search across all agents' knowledge bases:**

```
Grep pattern: "pricing strategy"
     path: agents/
     glob: "*/knowledge/**"
     output_mode: content
```

**Example -- list all knowledge files for an agent:**

```
Glob pattern: "agents/research-rachel/knowledge/**"
```

**Company-wide knowledge** is also available at `drive/`:

```
Grep pattern: "company vision"
     path: drive/
     output_mode: content
```

---

### Upload to Knowledge Base

Write a file into the agent's knowledge directory.

**Files:** `agents/{slug}/knowledge/{filename}`

**Example:**

```
# Create the knowledge directory if it doesn't exist
Bash: mkdir -p agents/research-rachel/knowledge

# Write the knowledge file
Write agents/research-rachel/knowledge/competitor-landscape-2026.md
  content: (your content here)
```

**Supported formats:** Markdown (`.md`), plain text (`.txt`), JSON (`.json`), YAML (`.yaml`), CSV (`.csv`)

**Register in database for cross-agent discovery:**

```bash
sqlite3 data/workspace.db "INSERT INTO agent_knowledge_bases (agent_slug, kb_id, access_level)
  VALUES ('research-rachel', 'competitor-landscape-2026', 'read');"
```

---

### Assign Knowledge Base

Copy knowledge files from one agent to another, or link a shared knowledge base.

**Files:**
- Source: `agents/{source-slug}/knowledge/{filename}`
- Target: `agents/{target-slug}/knowledge/{filename}`

**Example -- copy a specific file:**

```
# Read the source file
Read agents/research-rachel/knowledge/competitor-landscape-2026.md

# Write to the target agent's knowledge
Write agents/content-chris/knowledge/competitor-landscape-2026.md
  content: (paste content)
```

**Example -- copy an entire knowledge base:**

```bash
mkdir -p agents/content-chris/knowledge
cp agents/research-rachel/knowledge/* agents/content-chris/knowledge/
```

**Register the assignment in the database:**

```bash
sqlite3 data/workspace.db "INSERT INTO agent_knowledge_bases (agent_slug, kb_id, access_level)
  VALUES ('content-chris', 'competitor-landscape-2026', 'read');"
```

---

## Channel Management

### Create a Channel

Use the MCP platform tool. It handles domain creation, DB registration, and filesystem scaffolding.

```
mcp__platform__create_channel({
  name: "Content Strategy",
  project_id: "marketing",
  description: "Content planning and strategy",
  agent_ids: ["curator-carla", "content-writer"]
})
```

Channel slugs are auto-formatted as `{project_id}--{name-slug}` (e.g., `marketing--content-strategy`).

---

### Add Agent to Channel

Use the MCP platform tool. It updates all 4 sources of truth (config.json channels[], index.json, channel_members table, lead_agent_slug).

```
mcp__platform__add_to_channel({
  channel_id: "marketing--content-strategy",
  agent_id: "research-rachel",
  role: "member"
})
```

**Roles:** `lead`, `member`, `observer`

---

## Task Management

### Create a Task

Use the MCP platform tool:

```
mcp__platform__create_task({
  channel_id: "marketing--content-strategy",
  title: "Deep dive on competitor pricing",
  description: "Perform a deep competitive analysis of the top 5 AI workforce platforms.",
  assigned_agent_ids: ["research-rachel"],
  priority: "high"
})
```

---

## Skill Management

### Create a Skill

Write skill files to the marketplace. Every skill needs a `SKILL.md` (the skill definition) and a `xerushub.json` (marketplace metadata).

**Files:**
- `marketplace/skills/{slug}/SKILL.md` -- skill instructions and prompts
- `marketplace/skills/{slug}/xerushub.json` -- marketplace metadata
- `marketplace/skills/{slug}/references/` -- optional reference materials

**Example:**

```
Write marketplace/skills/social-listening/SKILL.md
```

**SKILL.md structure:**

```markdown
# Social Listening

Monitors social media platforms for brand mentions, sentiment shifts, and trending conversations.

## When to Use

- User asks to monitor social media mentions
- User wants sentiment analysis on a topic
- User needs trend reports from social platforms

## Instructions

1. Identify target keywords and platforms
2. Use Firecrawl to gather mentions
3. Analyze sentiment distribution
4. Generate summary report with actionable insights

## Output Format

Write results to:
- `output/deliverables/social-listening-{date}.md` (human-readable report)
- `data/company.db` (structured data in `research_reports` table)
```

```
Write marketplace/skills/social-listening/xerushub.json
```

**xerushub.json structure:**

```json
{
  "slug": "social-listening",
  "displayName": "Social Listening",
  "summary": "Monitor social media for brand mentions and sentiment analysis",
  "tags": ["social-media", "sentiment", "monitoring"],
  "version": "1.0.0"
}
```

**Register in the database:**

```bash
sqlite3 data/workspace.db "INSERT INTO skills (slug, name, version, source, source_ref, description, categories)
  VALUES ('social-listening', 'Social Listening', '1.0.0', 'local',
  'marketplace/skills/social-listening', 'Monitor social media for brand mentions',
  '[\"research\", \"social-media\"]');"
```

---

### Search Skills

Search available skills by name, content, or tags.

**Files:** `marketplace/skills/*/SKILL.md` and `marketplace/skills/*/xerushub.json`

**Example -- find skills by keyword in SKILL.md:**

```
Grep pattern: "sentiment"
     path: marketplace/skills/
     glob: "**/SKILL.md"
     output_mode: content
```

**Example -- list all available skills:**

```
Glob pattern: "marketplace/skills/*/SKILL.md"
```

**Example -- search by tag in xerushub.json:**

```
Grep pattern: '"social-media"'
     path: marketplace/skills/
     glob: "**/xerushub.json"
     output_mode: content
```

**Example -- search installed skills in the database:**

```bash
sqlite3 data/workspace.db "SELECT slug, name, version, description FROM skills WHERE categories LIKE '%research%';"
```

---

### Install a Skill

Install a skill by copying it from the marketplace to the agent's skill set, or reference it in the `.claude/skills/` directory.

**Option A -- Install as a Claude Code skill (auto-discovered):**

```bash
# Copy the skill to .claude/skills/
cp -r marketplace/skills/social-listening/ .claude/skills/social-listening/
```

The SDK auto-discovers skills in `.claude/skills/` and makes them available to all agents.

**Option B -- Assign a skill to a specific agent:**

```bash
sqlite3 data/workspace.db "INSERT INTO agent_skills (agent_slug, skill_slug, enabled)
  VALUES ('research-rachel', 'social-listening', 1);"
```

Then reference it in the agent's config:

```
# Read the agent config
Read agents/research-rachel/config.json

# Add the skill to the agent's tools/skills list
Edit agents/research-rachel/config.json
  old_string: '"tools": ["firecrawl"]'
  new_string: '"tools": ["firecrawl"], "skills": ["social-listening"]'
```

---

## Memory Operations

### Write Memory (filesystem)

Memory is organized hierarchically in `.memory/`. Write markdown files to the appropriate scope and type directory.

**Directory structure:**

```
.memory/
  agents/{slug}/           Agent-scoped memory
    working.md             Active state, current task progress
    expertise.md           Learned capabilities and patterns
  company/                 Company-scoped memory
    decisions.md           Architectural decisions log
    vision.md              Company vision and strategy
  entities/                Knowledge graph entities
    companies/             Discovered companies
    people/                Discovered people
    products/              Discovered products
    topics/                Tracked topics
  projects/                Project-scoped memory
  shared/                  Cross-agent shared memory
  topics/                  Topic-scoped memory
  user/                    User preferences
  archive/                 Archived/compressed memories
  index.md                 Master index with backlinks
```

**Example -- write agent working memory:**

```
Write .memory/agents/research-rachel/working.md
```

```markdown
# Working Memory: Research Rachel

## Current Task
Competitor analysis for AI workforce platforms

## Progress
- [x] Identified top 5 competitors
- [x] Gathered pricing data
- [ ] Feature comparison matrix
- [ ] Final report

## Key Findings
- Platform A has aggressive pricing at $29/agent/month
- Platform B focuses on enterprise with custom pricing

## Last Updated
2026-04-03T10:30:00Z
```

**Example -- write an entity file:**

```
Write .memory/entities/companies/platform-a.md
```

```markdown
# Platform A

## Overview
AI agent platform focused on SMB market.

## Key Data
- **Pricing**: $29/agent/month
- **Founded**: 2024
- **Funding**: Series A, $15M

## Backlinks
- [[.memory/agents/research-rachel/working.md]] -- discovered during competitor analysis
- [[data/company.db:competitors:1]] -- structured record

## Source
Firecrawl scan on 2026-04-03
```

**After writing memory, log the change:**

```bash
sqlite3 data/workspace.db "INSERT INTO memory_evolution_log (agent_slug, memory_path, operation, change_summary)
  VALUES ('research-rachel', '.memory/entities/companies/platform-a.md', 'create', 'New competitor entity discovered');"
```

---

### Query Memory (MCP -- requires backend)

For semantic search across memories using vector embeddings, use the `mcp__platform__query_memory` tool. This searches the pgvector index on Neon PostgreSQL.

```
Tool call: mcp__platform__query_memory
  query: "competitor pricing AI workforce"
  scope: "company"       -- optional: "agent", "company", "project", "shared"
  limit: 10              -- optional: max results
```

For local (non-semantic) memory search, use Grep directly:

```
Grep pattern: "competitor.*pricing"
     path: .memory/
     output_mode: content
```

---

### Analyze Memory Patterns (MCP -- requires backend)

Use the `mcp__platform__analyze_memory_patterns` tool for pattern analysis across the memory corpus.

```
Tool call: mcp__platform__analyze_memory_patterns
  agent_slug: "research-rachel"    -- optional: scope to one agent
  pattern_type: "workflow"         -- optional: workflow, code, communication, error, optimization
```

---

## Status and Monitoring

### Get Status (MCP -- requires backend)

Use the `mcp__platform__get_status` tool for live platform, agent, and sandbox status.

```
Tool call: mcp__platform__get_status
  scope: "platform"   -- "platform", "agent", "sandbox"
  agent_slug: ""       -- optional: specific agent
```

For local agent status from the database:

```bash
sqlite3 data/workspace.db "SELECT slug, name, status, autonomy_level FROM agents ORDER BY status, slug;"
```

For execution session status:

```bash
sqlite3 data/workspace.db "SELECT * FROM v_active_sessions;"
sqlite3 data/workspace.db "SELECT * FROM v_agent_workload;"
```

---

### List Domains

Query domains from the workspace database.

**Database:** `data/workspace.db`
**Table:** `domains`

```bash
sqlite3 data/workspace.db "SELECT slug, name, description FROM domains ORDER BY slug;"
```

**With channels:**

```bash
sqlite3 data/workspace.db "SELECT d.slug as domain, d.name as domain_name, c.slug as channel, c.name as channel_name, c.lead_agent_slug
  FROM domains d
  LEFT JOIN channels c ON d.slug = c.domain_slug
  ORDER BY d.slug, c.slug;"
```

**Schema reference -- `domains` table:**

| Column | Type | Description |
|--------|------|-------------|
| `slug` | TEXT PK | Domain identifier |
| `name` | TEXT | Display name |
| `description` | TEXT | Domain purpose |
| `config` | TEXT (JSON) | Domain settings |

---

## Output Management

### Search Outputs

Search agent output files (deliverables, reports, posts) across the workspace.

**Output locations:**

| Location | Content |
|----------|---------|
| `projects/{domain}/channels/{channel}/output/deliverables/` | Final deliverables |
| `projects/{domain}/channels/{channel}/output/posts.jsonl` | Channel messages |
| `projects/{domain}/channels/{channel}/scratch/` | Work in progress |
| `agents/{slug}/data/output/` | Agent-specific outputs (if used) |

**Example -- search deliverables by content:**

```
Grep pattern: "competitor analysis"
     path: projects/
     glob: "**/output/deliverables/*.md"
     output_mode: content
```

**Example -- list all deliverables across channels:**

```
Glob pattern: "projects/**/output/deliverables/*"
```

**Example -- search channel posts:**

```
Grep pattern: "thread ready"
     path: projects/
     glob: "**/output/posts.jsonl"
     output_mode: content
```

**Example -- search from the database (agent_outputs table):**

```bash
sqlite3 data/workspace.db "SELECT agent_slug, title, output_type, file_path, created_at
  FROM agent_outputs
  WHERE output_type = 'report'
  ORDER BY created_at DESC
  LIMIT 20;"
```

**Schema reference -- `agent_outputs` table:**

| Column | Type | Description |
|--------|------|-------------|
| `agent_slug` | TEXT FK | Producing agent |
| `output_type` | TEXT | `file`, `report`, `analysis`, `code`, `data`, `other` |
| `title` | TEXT | Output title |
| `file_path` | TEXT | Path to the output file |
| `content_preview` | TEXT | First ~500 chars |

---

## Filesystem vs MCP

Filesystem (sqlite3 + Read/Write) is the primary path for workspace operations. MCP tools are an alternative that routes through the backend. Use MCP for operations requiring backend features (pgvector search, notifications, billing, OAuth).

---

## MCP Tools Reference (All 38 Tools)

MCP tools are called using the format: `mcp__platform__<tool_name>`

All 38 platform tools available via the `platform` MCP server. These route through the Xerus backend and provide capabilities beyond what the local filesystem offers.

### Session Control (5)

| # | Tool | Purpose |
|---|------|---------|
| 1 | `mcp__platform__pause_execution` | Pause agent execution for human approval |
| 2 | `mcp__platform__resume_execution` | Resume agent after approval |
| 3 | `mcp__platform__get_session_state` | Query current execution session status |
| 4 | `mcp__platform__complete_session` | Signal that a session is complete |
| 5 | `mcp__platform__cancel_execution` | Cancel an in-progress execution |

### Agent Management (6)

| # | Tool | Purpose |
|---|------|---------|
| 6 | `mcp__platform__search_agents` | Search agents by name, role, or capability |
| 7 | `mcp__platform__list_agents` | List all installed agents with status |
| 8 | `mcp__platform__create_agent` | Create a new agent (backend registration + workspace files) |
| 9 | `mcp__platform__clone_agent` | Clone an existing agent with new identity |
| 10 | `mcp__platform__update_agent` | Update agent config, model, or autonomy level |
| 11 | `mcp__platform__delete_agent` | Remove an agent and clean up resources |

### Knowledge Base (3)

| # | Tool | Purpose |
|---|------|---------|
| 12 | `mcp__platform__search_kb` | Search knowledge bases (pgvector semantic search) |
| 13 | `mcp__platform__upload_kb` | Upload a document to an agent's knowledge base |
| 14 | `mcp__platform__assign_kb` | Assign a knowledge base to an agent |

### Channels & Tasks (4)

| # | Tool | Purpose |
|---|------|---------|
| 15 | `mcp__platform__create_channel` | Create a team channel under a domain |
| 16 | `mcp__platform__add_to_channel` | Add an agent to a channel with a role |
| 17 | `mcp__platform__create_task` | Create a task and deliver to an agent's inbox |
| 18 | `mcp__platform__list_domains` | List all organizational domains |

### Skills (4)

| # | Tool | Purpose |
|---|------|---------|
| 19 | `mcp__platform__search_skills` | Search the skill marketplace |
| 20 | `mcp__platform__create_skill` | Create a new skill definition |
| 21 | `mcp__platform__install_skill` | Install a skill for an agent |
| 22 | `mcp__platform__uninstall_skill` | Remove an installed skill from an agent |

### Memory (3)

| # | Tool | Purpose |
|---|------|---------|
| 23 | `mcp__platform__query_memory` | Semantic search across memories (pgvector) |
| 24 | `mcp__platform__write_memory` | Write a memory entry via the backend |
| 25 | `mcp__platform__analyze_memory_patterns` | Pattern analysis across the memory corpus |

### Outputs (1)

| # | Tool | Purpose |
|---|------|---------|
| 26 | `mcp__platform__search_outputs` | Search agent outputs and deliverables |

### Integrations (2)

| # | Tool | Purpose |
|---|------|---------|
| 27 | `mcp__platform__connect_tool` | Connect an OAuth tool (Pipedream) |
| 28 | `mcp__platform__search_tools` | Search available integrations and connected accounts |

### Triggers (3)

| # | Tool | Purpose |
|---|------|---------|
| 29 | `mcp__platform__register_trigger` | Register a webhook or event trigger |
| 30 | `mcp__platform__deregister_trigger` | Remove a registered trigger |
| 31 | `mcp__platform__list_triggers` | List all registered triggers |

### Communication (1)

| # | Tool | Purpose |
|---|------|---------|
| 32 | `mcp__platform__send_notification` | Send a notification to the user |

### Status (2)

| # | Tool | Purpose |
|---|------|---------|
| 33 | `mcp__platform__get_status` | Platform, agent, or sandbox status |
| 34 | `mcp__platform__get_billing_status` | Current billing usage and budget remaining |

### Scheduling (4)

| # | Tool | Purpose |
|---|------|---------|
| 35 | `mcp__platform__create_schedule` | Create a recurring schedule for an agent |
| 36 | `mcp__platform__list_schedules` | List all active schedules |
| 37 | `mcp__platform__update_schedule` | Update an existing schedule |
| 38 | `mcp__platform__delete_schedule` | Remove a schedule |

---

## Database Quick Reference

The workspace uses two SQLite databases:

### `data/company.db` (business data)

Defined in `data/schema.sql`. Core tables:

| Table | Purpose |
|-------|---------|
| `research_reports` | Research outputs from any agent |
| `prospects` | Discovered companies and people |
| `competitors` | Competitor profiles |
| `topics` | Tracked topics and trends |
| `google_files` | Google Workspace file registry |
| `entity_registry` | Links `.memory/entities/` paths to DB rows |
| `metrics` | Time-series metrics (generic) |

### Workspace execution tables (in `workspace.db`)

Defined in `data/workspace-schema.sql`. Key tables for agent operations:

| Table | Purpose |
|-------|---------|
| `agents` | Installed agents |
| `agent_tools` | Tools assigned to agents |
| `agent_knowledge_bases` | KB assignments |
| `agent_skills` | Skill assignments |
| `agent_triggers` | Event triggers |
| `domains` | Organizational domains |
| `channels` | Team channels |
| `channel_members` | Agent-channel membership |
| `channel_messages` | Message backup/query store |
| `execution_sessions` | Agent execution tracking |
| `execution_queue` | Pending work items |
| `inbox_items` | Agent inbox messages |
| `agent_outputs` | Deliverables registry |
| `skills` | Installed skills registry |
| `tasks` | Beads tasks mirror |
| `cost_events` | Cost tracking |
| `memory_evolution_log` | Memory change audit trail |
| `discovered_patterns` | Learned patterns |

### Useful views:

| View | Returns |
|------|---------|
| `v_active_sessions` | Currently running sessions |
| `v_pending_approvals` | HITL items awaiting human action |
| `v_agent_workload` | Work per agent (sessions, queue, inbox) |
| `v_daily_costs` | Costs aggregated by day |
