# Workspace Operations Guide

> This guide documents how to perform platform operations using workspace files.
> These operations were previously MCP tools but are now filesystem-native.
> Use Claude Code's built-in tools (Read, Write, Bash, Glob, Grep) for all operations below.

## Quick Reference

| Operation | Tool(s) | Primary Path |
|-----------|---------|-------------|
| Create Agent | Write | `agents/{slug}/config.json` + `agents/{slug}/agent.md` |
| Update Agent | Read + Edit | `agents/{slug}/config.json` |
| Search Agents | Glob + Read | `agents/*/config.json` |
| Clone Agent | Read + Write | `agents/{source}/` -> `agents/{target}/` |
| Delete Agent | Bash | `agents/{slug}/` |
| List Agents | Glob | `agents/*/config.json` |
| Search KB | Grep / Glob | `agents/{slug}/knowledge/` |
| Upload to KB | Write | `agents/{slug}/knowledge/{filename}` |
| Assign KB | Read + Write | Copy between `agents/*/knowledge/` |
| Create Channel | Bash (sqlite3) | `data/workspace-schema.sql` -> `channels` table |
| Add Agent to Channel | Bash (sqlite3) | `channel_members` table |
| Create Task | Write | `agents/{slug}/inbox/{task-id}.md` |
| Create Skill | Write | `marketplace/skills/{slug}/SKILL.md` |
| Search Skills | Glob + Grep | `marketplace/skills/*/SKILL.md` |
| Install Skill | Edit | Agent config or `.claude/settings.json` |
| Write Memory | Write | `.memory/{scope}/{type}/{filename}.md` |
| Query Memory | MCP | `query_memory` (pgvector semantic search) |
| Get Status | MCP | `get_status` |
| List Domains | Bash (sqlite3) | `domains` table |
| Search Outputs | Glob + Grep | `agents/{slug}/data/output/` or channel `output/` |

---

## Agent Management

### Create an Agent

Write two files to `agents/{slug}/`: a `config.json` with the agent's operational config, and an `agent.md` with the agent's system prompt and personality.

**Files:**
- `agents/{slug}/config.json` -- operational configuration
- `agents/{slug}/agent.md` -- system prompt, identity, goals

**config.json structure:**

```json
{
  "slug": "research-rachel",
  "name": "Research Rachel",
  "description": "Market research specialist...",
  "role": "research",
  "model": "claude-sonnet-4.5",
  "autonomy_level": "supervised",
  "domain": "",
  "primary_channel": "",
  "channels": [],
  "tools": ["firecrawl"],
  "heartbeat_cron": "",
  "mascot": ""
}
```

**agent.md frontmatter structure:**

```yaml
---
name: Research Rachel
slug: research-rachel
description: Market research specialist...
personality_type: analytical
ai_model: claude-sonnet-4.5
category: research
tags: [research, analysis, market]
autonomy_level: supervised
tools: [firecrawl]
skills: [market_analysis]
model_config:
  temperature: 0.5
  top_p: 0.9
  max_tokens: 4000
permissions:
  can_write_files: true
  can_send_emails: false
  can_create_tasks: true
---
```

**Steps:**

1. Create the agent directory and both files:

```
# Write config.json
Write agents/research-rachel/config.json

# Write agent.md (frontmatter + system prompt)
Write agents/research-rachel/agent.md
```

2. Register the agent in the workspace database:

```bash
sqlite3 data/workspace.db "INSERT INTO agents (slug, name, adapter_type, role, autonomy_level, status, config)
  VALUES ('research-rachel', 'Research Rachel', 'claudecode', 'research', 'supervised', 'idle',
  '{\"model\": \"claude-sonnet-4.5\", \"temperature\": 0.5}');"
```

3. Update the agents index:

```
# Read agents/index.json, add the new agent entry, then Write it back
```

4. Create supporting directories:

```bash
mkdir -p agents/research-rachel/knowledge
mkdir -p agents/research-rachel/inbox
mkdir -p .memory/agents/research-rachel
```

5. Initialize agent memory files:

```
Write .memory/agents/research-rachel/working.md
Write .memory/agents/research-rachel/expertise.md
```

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

Copy all files from the source agent directory to a new target directory, then update the slug, name, and any identity fields.

**Files:**
- Source: `agents/{source-slug}/`
- Target: `agents/{target-slug}/`

**Steps:**

1. Read source files:

```
Read agents/research-rachel/config.json
Read agents/research-rachel/agent.md
```

2. Write to target with updated identity:

```
# Write config.json with new slug/name
Write agents/research-rachel-v2/config.json
  (paste content with slug and name changed)

# Write agent.md with new identity
Write agents/research-rachel-v2/agent.md
  (paste content with slug and name changed)
```

3. Copy knowledge base files if present:

```bash
cp -r agents/research-rachel/knowledge/ agents/research-rachel-v2/knowledge/ 2>/dev/null
```

4. Create supporting structure:

```bash
mkdir -p agents/research-rachel-v2/inbox
mkdir -p .memory/agents/research-rachel-v2
touch .memory/agents/research-rachel-v2/working.md
touch .memory/agents/research-rachel-v2/expertise.md
```

5. Register the clone in the database:

```bash
sqlite3 data/workspace.db "INSERT INTO agents (slug, name, adapter_type, role, autonomy_level, status, config)
  SELECT 'research-rachel-v2', 'Research Rachel V2', adapter_type, role, autonomy_level, 'idle', config
  FROM agents WHERE slug = 'research-rachel';"
```

---

### Delete an Agent

Remove the agent directory, its memory, and its database records.

**Files:**
- `agents/{slug}/` -- agent definition
- `.memory/agents/{slug}/` -- agent memory

**Steps:**

1. Remove from database first (cascades to related tables):

```bash
sqlite3 data/workspace.db "DELETE FROM agents WHERE slug = 'research-rachel';"
```

2. Remove filesystem artifacts:

```bash
rm -rf agents/research-rachel/
rm -rf .memory/agents/research-rachel/
```

3. Update the agents index:

```
# Read agents/index.json, remove the entry, Write it back
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

Channels are stored in the `channels` table of the workspace database. They live under domains (organizational units).

**Database:** `data/workspace.db`
**Tables:** `domains`, `channels`

**Steps:**

1. Ensure the domain exists (create if needed):

```bash
sqlite3 data/workspace.db "INSERT OR IGNORE INTO domains (slug, name, description)
  VALUES ('marketing', 'Marketing', 'Marketing department');"
```

2. Create the channel:

```bash
sqlite3 data/workspace.db "INSERT INTO channels (slug, name, domain_slug, lead_agent_slug, description, goals)
  VALUES (
    'content-strategy',
    'Content Strategy',
    'marketing',
    'curator-carla',
    'Channel for content planning and strategy',
    '{\"primary\": \"Create 10 content pieces per week\", \"metrics\": [\"engagement_rate\", \"publish_count\"]}'
  );"
```

3. Create the channel's filesystem structure under the project:

```bash
mkdir -p projects/marketing/channels/content-strategy/output/deliverables
mkdir -p projects/marketing/channels/content-strategy/scratch
touch projects/marketing/channels/content-strategy/output/posts.jsonl
```

4. Write the channel's CLAUDE.md:

```
Write projects/marketing/channels/content-strategy/CLAUDE.md
  content: (channel mission, goals, metrics, team, rules)
```

**Schema reference -- `channels` table:**

| Column | Type | Description |
|--------|------|-------------|
| `slug` | TEXT PK | Channel identifier |
| `name` | TEXT | Display name |
| `domain_slug` | TEXT FK | Parent domain |
| `lead_agent_slug` | TEXT FK | Channel manager agent |
| `description` | TEXT | Channel purpose |
| `goals` | TEXT (JSON) | Goals and metrics |
| `config` | TEXT (JSON) | Channel settings |

---

### Add Agent to Channel

Insert a record into the `channel_members` table.

**Database:** `data/workspace.db`
**Table:** `channel_members`

**Example:**

```bash
sqlite3 data/workspace.db "INSERT INTO channel_members (channel_slug, agent_slug, role)
  VALUES ('content-strategy', 'research-rachel', 'member');"
```

**Roles:** `lead`, `member`, `observer`

**List current channel members:**

```bash
sqlite3 data/workspace.db "SELECT cm.agent_slug, cm.role, a.name
  FROM channel_members cm
  JOIN agents a ON cm.agent_slug = a.slug
  WHERE cm.channel_slug = 'content-strategy';"
```

**Schema reference -- `channel_members` table:**

| Column | Type | Description |
|--------|------|-------------|
| `id` | INTEGER PK | Auto-increment ID |
| `channel_slug` | TEXT FK | Channel reference |
| `agent_slug` | TEXT FK | Agent reference |
| `role` | TEXT | `lead`, `member`, or `observer` |
| `joined_at` | TEXT | ISO timestamp |

---

## Task Management

### Create a Task

Write a task file to an agent's inbox directory. The backend also mirrors tasks in the `inbox_items` table.

**Files:** `agents/{slug}/inbox/{task-id}.md`

**Example:**

```
Write agents/research-rachel/inbox/task-2026-04-03-competitor-deep-dive.md
```

**Task file format:**

```markdown
---
id: task-2026-04-03-competitor-deep-dive
type: task
from: xerus-master
priority: high
subject: Deep dive on competitor pricing
created_at: 2026-04-03T10:00:00Z
---

## Task

Perform a deep competitive analysis of the top 5 AI workforce platforms.
Focus on pricing models, feature comparison, and market positioning.

## Deliverables

- `output/deliverables/competitor-analysis-q2-2026.md`
- Update `data/company.db` competitors table

## Deadline

2026-04-05T17:00:00Z
```

**Also register in the database for queryability:**

```bash
sqlite3 data/workspace.db "INSERT INTO inbox_items (agent_slug, sender_slug, message_type, subject, content, priority)
  VALUES ('research-rachel', 'xerus-master', 'task', 'Deep dive on competitor pricing',
  'Perform a deep competitive analysis...', 'high');"
```

**Schema reference -- `inbox_items` table:**

| Column | Type | Description |
|--------|------|-------------|
| `agent_slug` | TEXT FK | Receiving agent |
| `sender_slug` | TEXT | Sending agent (null for system) |
| `message_type` | TEXT | `coordination`, `system`, `task`, `notification` |
| `subject` | TEXT | Brief subject line |
| `content` | TEXT | Full message body |
| `priority` | TEXT | `urgent`, `high`, `normal`, `low` |
| `status` | TEXT | `unread`, `read`, `actioned`, `archived` |

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

For semantic search across memories using vector embeddings, use the `query_memory` MCP tool. This searches the pgvector index on Neon PostgreSQL.

```
MCP call: query_memory
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

Use the `analyze_memory_patterns` MCP tool for pattern analysis across the memory corpus.

```
MCP call: analyze_memory_patterns
  agent_slug: "research-rachel"    -- optional: scope to one agent
  pattern_type: "workflow"         -- optional: workflow, code, communication, error, optimization
```

---

## Status and Monitoring

### Get Status (MCP -- requires backend)

Use the `get_status` MCP tool for live platform, agent, and sandbox status.

```
MCP call: get_status
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

## MCP Tools Reference (Still Available)

These 13 operations require backend state and are called via the MCP server, not filesystem:

| # | Tool | Purpose |
|---|------|---------|
| 1 | `pause_execution` | Pause agent for human approval |
| 2 | `resume_execution` | Resume after approval |
| 3 | `get_session_state` | Query current session status |
| 4 | `complete_session` | Signal session is complete |
| 5 | `connect_tool` | Connect OAuth tool (Pipedream) |
| 6 | `register_trigger` | Register webhook trigger |
| 7 | `deregister_trigger` | Remove webhook trigger |
| 8 | `send_notification` | Send user notification |
| 9 | `search_tools` | Search available integrations |
| 10 | `query_memory` | Semantic search across memories (pgvector) |
| 11 | `analyze_memory_patterns` | Pattern analysis on memories |
| 12 | `list_triggers` | List registered triggers |
| 13 | `get_status` | Platform/agent/sandbox status |

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
