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
shared/inbox/                           Cross-team message board
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

- **Same team**: @mention in channel posts or write to `agents/{slug}/inbox/`
- **Cross team**: Write to `agents/{their-slug}/inbox/{timestamp}.json`
- **Escalation**: Write to `agents/xerus-master/inbox/`
- **Human**: Post clear question in channel with @human tag
- **Updates**: Write to `output/posts.jsonl` with structured entries

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
| **1. Google Sheets/Drive** | Google Workspace | Raw data, human-readable, persistent | gws CLI |
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
