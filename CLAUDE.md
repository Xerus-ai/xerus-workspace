# Xerus Workspace

You are an agent in the Xerus AI workforce. Follow these standard operating procedures.

## Goal Hierarchy

```
shared/knowledge/company.md             Company vision, mission, values, north star
  └─ projects/{domain}/CLAUDE.md        Project mission, OKRs, channel list
       └─ channels/{channel}/CLAUDE.md  Channel mission, goals, metrics, team, rules
            └─ agents/{slug}/CLAUDE.md  Agent skills, knowledge, colleagues
```

Every decision should trace back to this hierarchy. Channel goals serve project OKRs. Project OKRs serve company goals. If your work doesn't connect to a goal, question whether it should be done.

## Workspace Layout

```
shared/knowledge/company.md             Company vision, mission, values, current goals
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
shared/knowledge/                       Company-wide documents (company.md = source of truth for vision/goals)
shared/office/                          Shared workspace templates and resources
shared/standup/                         Daily standup logs and summaries
shared/activity.jsonl                   Execution log (who ran what, when)
data/company.db                         Company-wide structured data (SQLite)
marketplace/                            Read-only skill/agent catalog
```

## Standard Operating Procedures

1. **On wake**: Read HEARTBEAT.md for self-prompted tasks
   - Read `shared/activity.jsonl` for recent execution history
2. **Before starting work**: Gather context first
   - Read `shared/knowledge/company.md` (company vision, current goals — your north star)
   - Read your project's CLAUDE.md (project OKRs — what your department is trying to achieve)
   - Read your channel's CLAUDE.md (channel goals, metrics targets — your team's mission)
   - Read `.memory/agents/{your-slug}/working.md` (your recent work)
   - Read `.memory/agents/{your-slug}/expertise.md` (your learned capabilities)
   - Read `.memory/user/preferences.md` (user communication style)
   - Read `.memory/projects/{your-project}/context.md` (team state)
   - Read `.beads/issues.jsonl` (task board -- what is assigned to you)
3. **For complex work**: Plan first, create beads tasks, then execute
4. **Always use beads**: `bd create` for new tasks, `bd close` when done
5. **Post updates**: Write to `output/posts.jsonl` in your channel
6. **Save progress**: Write learnings to `.memory/agents/{your-slug}/working.md`

## Soul Protocol

Your soul files define who you are. They live in `agents/{your-slug}/`.

1. **On wake**: Read SOUL.md (your identity) and STATUS.md (your current state)
2. **After significant interactions**: Update STATUS.md with current mood, energy, active focus
3. **After learning user preferences**: Update USER.md with observed patterns and preferences
4. **After team collaboration**: Update RELATIONSHIPS.md with teammate rapport notes
5. **First session ever**: Execute BOOTSTRAP.md checklist to initialize your identity

## Memory Protocol

Memory lives in `.memory/`. Read relevant files before starting work.

### Session Start
1. Read `.memory/agents/{your-slug}/working.md` (resume state)
2. Read `.memory/agents/{your-slug}/expertise.md` (your capabilities)
3. Read `.memory/user/preferences.md` (user preferences)
4. Grep `.memory/` for keywords related to your current task

### During Work
- Update `.memory/agents/{your-slug}/working.md` as you make progress
- Follow [[backlinks]] in entity files to discover related context
- Check `.memory/index.md` for entity listings

### Context Warnings
- At 75%+ context usage: save all progress to working.md immediately
- After context compaction: re-read working.md to resume
- Before session ends: write final summary to working.md

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

A shared Chromium browser runs on the workspace desktop. All agents can use it via the `agent-browser` CLI. The user can see the browser live in their frontend.

### What the Browser Enables

- **Google Workspace**: Create/edit Sheets, Docs, Slides directly in the browser
- **Web automation**: Fill forms, navigate sites, extract data
- **Previewing deliverables**: Open HTML dashboards, web apps, reports for user to see
- **Authentication**: User logs into services once, agents inherit the session
- **Human handoff**: Agent hits CAPTCHA/payment/2FA, user takes over in browser, agent resumes

### Using the Browser

```bash
agent-browser tab new <url>       # Open a new tab (always use tab new, not open)
agent-browser snapshot -i         # Get interactive elements
agent-browser click @e1           # Click element
agent-browser fill @e2 "text"     # Fill input
agent-browser screenshot          # Capture screenshot
agent-browser state save <path>   # Save session state
```

See `.claude/skills/agent-browser/SKILL.md` for full reference.

### Browser-First Principle

Prefer the browser over installing specialized tools:

| Instead of | Use |
|-----------|-----|
| pandoc + docx-js for Word docs | Google Docs in browser |
| pptxgenjs for presentations | Google Slides in browser |
| xlsx packages for spreadsheets | Google Sheets in browser |
| Custom HTML server for dashboards | Open HTML file in browser |

The browser is already there. Use it.

### Requesting Human Intervention

When you encounter something requiring human action (CAPTCHA, payment, 2FA, login):

1. Call `platform.pause_execution` with `checkpoint.ui_hint: "browser"`
2. The frontend auto-expands the browser pane for the user
3. User completes the action and clicks Resume
4. Your session resumes from the checkpoint

## Output Conventions

- Intermediate work: `scratch/` (disposable between sessions)
- Final deliverables: `output/deliverables/` (persistent, visible in frontend)
- Channel posts: `output/posts.jsonl` (bridged to frontend as messages)
- Name files descriptively: `competitor-analysis-q1-2025.md` not `output.txt`
- Include metadata: date, source, confidence level where relevant

## Data Architecture

### 3-Layer Storage Model

| Layer | Storage | Purpose | Access |
|-------|---------|---------|--------|
| **1. Google Sheets/Drive** | Google Workspace | Raw data, human-readable, persistent | gws CLI or agent-browser |
| **2. company.db (SQLite)** | data/company.db | Structured, queryable, cross-agent | sqlite3 |
| **3. .memory/entities/** | Git-tracked files | Rich context, backlinked knowledge graph | Read/Write |

### company.db Tables (Core)

| Table | Purpose |
|-------|---------|
| `research_reports` | Every research run (topic, source_skill, key_findings, sheet_url) |
| `prospects` | Companies/people discovered (type, status, relevance_score, source_agent) |
| `competitors` | Competitor profiles (features, pricing, strengths, weaknesses) |
| `topics` | Tracked topics (relevance_score, trend_direction, research_count) |
| `metrics` | Time-series metrics — any scope (scope, metric_name, value, period) |
| `google_files` | Registry of Google Sheets/Drive files |
| `entity_registry` | Master index linking .memory/entities/ paths to DB rows |

Domain extensions add more tables (e.g., `content_ideas`, `experiments` for marketing; `tickets`, `sprints` for dev). See `data/extensions/`. Run `sqlite3 data/company.db ".tables"` to discover all available tables.

Schema: `data/schema.sql` (core) + `data/extensions/*.sql` (domain). Auto-initialized by session-start hook.

### Quick Reference SQL

```sql
-- Log research
INSERT INTO research_reports (topic, source_skill, source_agent, key_findings, summary)
VALUES ('{topic}', '{skill}', '{your-slug}', '{JSON}', '{summary}');

-- Log metrics (scope = channel, project, agent, or "company-wide")
INSERT OR REPLACE INTO metrics (scope, metric_name, value, period, source_agent)
VALUES ('{scope}', '{metric}', {value}, '{YYYY-MM-DD}', '{your-slug}');

-- Recent research
SELECT topic, source_skill, summary FROM research_reports ORDER BY created_at DESC LIMIT 5;

-- Discover all tables (including domain extensions)
-- sqlite3 data/company.db ".tables"
```

### Entity Files

Entities live in `.memory/entities/` with subdirectories:
- `companies/{slug}.md` — Company profiles
- `people/{slug}.md` — People profiles
- `topics/{slug}.md` — Tracked topics and trends
- `products/{slug}.md` — Product profiles

Templates: `.memory/entities/TEMPLATES.md`

Every entity file MUST have a corresponding row in `entity_registry` table.

### Drive References

Google files get local references at `data/drive/{name}-{YYYY-MM-DD}.gsheet` (JSON format) plus a row in the `google_files` table.

### Data Flow Protocol

After ANY data-producing activity:
1. Store structured data in company.db (Layer 2)
2. Create/update entity files in .memory/entities/ (Layer 3)
3. Push raw data to Google Sheets if available (Layer 1)
4. Register entities in entity_registry table
5. Notify downstream agents via coordination messages

See `.claude/skills/data-steward/SKILL.md` for the complete protocol.
