---
name: data-steward
description: "Ecosystem data protocol. Ensures all data flows through the 3-layer model: Google Sheets (raw) → company.db (structured) → .memory/entities/ (rich context). Not user-invocable — behavioral protocol for all agents."
user-invocable: false
scope: all-agents
---

# Data Steward Protocol

You are part of a data ecosystem. Every piece of data you produce has downstream consumers. Think in ecosystem, not individuality.

## 3-Layer Storage Model

```
Layer 1: Google Sheets/Drive  → Raw data, persistent, human-readable
         Access: gws CLI (batch) or agent-browser (interactive)
Layer 2: data/company.db      → Structured, queryable, cross-agent
Layer 3: .memory/entities/    → Rich context, backlinked knowledge graph
```

### Layer 1 Access Methods

| Method | When to Use |
|--------|-------------|
| `gws` CLI | Batch operations (append 100+ rows, bulk reads, headless automation) |
| `agent-browser` | Interactive work (create formatted docs, complex spreadsheets, presentations) |
| Browser direct | User-facing previews (dashboards, reports the user wants to see) |

See `.claude/skills/google-workspace/SKILL.md` for CLI patterns and `.claude/skills/agent-browser/SKILL.md` for browser patterns.

**After ANY data-producing activity**, store in all applicable layers:

| Data Type | Layer 1 (Sheets) | Layer 2 (DB) | Layer 3 (Entities) |
|-----------|-----------------|--------------|-------------------|
| Research findings | Research sheet | research_reports | topics/, companies/ |
| Competitor info | — | competitors | companies/ |
| Prospect discovered | — | prospects | companies/ or people/ |
| Topic/trend | — | topics | topics/ |
| Metrics collected | Metrics sheet | metrics | — |
| Google file created | — | google_files | — |

> **Extensibility**: Your workspace may have domain-specific tables beyond these core tables (e.g., `content_ideas`, `experiments`, `campaign_metrics` for marketing; `tickets`, `sprints` for dev). Check your project or channel CLAUDE.md for domain-specific storage instructions. Use `sqlite3 data/company.db ".tables"` to see what's available.

## After Research Protocol

When you complete any research activity (last30days, apify, trend-research, web search, or any data-gathering skill):

1. **Insert research_reports row**:
   ```sql
   INSERT INTO research_reports (topic, source_skill, source_agent, key_findings, summary, sheet_url, raw_data_path)
   VALUES ('{topic}', '{skill}', '{your-slug}', '{JSON findings}', '{summary}', '{sheet_url}', '{path}');
   ```

2. **Extract entities** — scan findings for companies, people, topics, products:
   - For each entity, follow the Entity Extraction Protocol below

3. **Store domain-specific data** — if your workspace has tables like `content_ideas`, `tickets`, etc., insert relevant rows there too. Check your channel/project CLAUDE.md for guidance.

4. **Notify downstream** — use the Downstream Notification Protocol below

## After Data Collection Protocol

When you collect metrics, run experiments, or gather any quantitative data:

1. **Insert metrics rows**:
   ```sql
   INSERT OR REPLACE INTO metrics (scope, metric_name, value, period, source_agent, tags, notes)
   VALUES ('{scope}', '{metric}', {value}, '{YYYY-MM-DD}', '{your-slug}', '{tags}', '{notes}');
   ```
   `scope` = whatever grouping makes sense: channel name, project name, agent slug, "company-wide", etc.

2. **Update context files** — write latest metrics to relevant context.md files

3. **Write dashboard data** if applicable — `shared/dashboard/data/{scope}.json`

## Entity Extraction Protocol

When you discover a company, person, topic, or product:

### Step 1: Create entity file
Use templates from `.memory/entities/TEMPLATES.md`:
- Company → `.memory/entities/companies/{slug}.md`
- Person → `.memory/entities/people/{slug}.md`
- Topic → `.memory/entities/topics/{slug}.md`
- Product → `.memory/entities/products/{slug}.md`

Slug format: lowercase, hyphens, no special chars. Example: `openai`, `sam-altman`, `ai-agents`, `cursor-ide`.

### Step 2: Insert DB row

For companies/people:
```sql
INSERT INTO prospects (name, type, status, relevance_score, source_agent, source_url, entity_path)
VALUES ('{name}', '{company|person}', 'discovered', {score}, '{your-slug}', '{url}', '.memory/entities/{type}/{slug}.md');
```

For competitors:
```sql
INSERT INTO competitors (name, website, category, features, pricing, strengths, weaknesses, source_agent, entity_path)
VALUES ('{name}', '{url}', '{cat}', '{features}', '{pricing}', '{strengths}', '{weaknesses}', '{your-slug}', '.memory/entities/companies/{slug}.md');
```

For topics:
```sql
INSERT INTO topics (name, description, relevance_score, trend_direction, source_agent, entity_path)
VALUES ('{name}', '{desc}', {score}, '{rising|stable|declining}', '{your-slug}', '.memory/entities/topics/{slug}.md');
```

### Step 3: Insert entity_registry row
```sql
INSERT INTO entity_registry (entity_type, entity_slug, entity_path, db_table, db_id, source_agent)
VALUES ('{type}', '{slug}', '.memory/entities/{type}/{slug}.md', '{table}', {last_insert_rowid}, '{your-slug}');
```

### Step 4: Add backlinks
In the new entity file, add `[[backlinks]]` to related entities. Also update related entity files to backlink to the new one.

## Downstream Notification Protocol

After producing data, notify agents who consume it. **Look up who to notify from your channel/project CLAUDE.md** — team structures vary per workspace.

General rules:
| Data Produced | Who to Notify |
|--------------|---------------|
| Research report | Your channel lead + agents whose work depends on research |
| Competitor analysis | Strategy/growth agents in your org |
| New entity discovered | xerus-master (always) + relevant domain agents |
| Metrics update | Whoever tracks metrics in your org |
| Trending topic | Content/research agents in your org |

Read your **Module CLAUDE.md → Colleagues** section to identify who works with you. Read your **channel CLAUDE.md → Cross-Channel** section to find agents in other teams.

Coordination message format:
```json
{"agent_slug":"{your-slug}","content":"[data-steward] New {type}: {summary}. See {path/table}.","message_type":"coordination","metadata":{"target_agent":"{slug}"},"posted_at":"{ISO}"}
```

## SQLite Quick Reference

**Open DB:**
```bash
sqlite3 data/company.db
```

**Discover available tables:**
```bash
sqlite3 data/company.db ".tables"
sqlite3 data/company.db ".schema {table_name}"
```

**Common queries:**
```sql
-- Recent research
SELECT topic, source_skill, summary, created_at FROM research_reports ORDER BY created_at DESC LIMIT 10;

-- Entity lookup
SELECT entity_type, entity_slug, entity_path, db_table, db_id FROM entity_registry WHERE entity_slug LIKE '%{search}%';

-- Prospects by relevance
SELECT name, type, status, relevance_score, source_agent FROM prospects ORDER BY relevance_score DESC LIMIT 20;

-- Metrics for a scope (last 7 days)
SELECT scope, metric_name, value, period FROM metrics WHERE period >= date('now', '-7 days') ORDER BY period DESC;

-- Topics by trend
SELECT name, relevance_score, trend_direction, research_count FROM topics ORDER BY relevance_score DESC;
```

## Data Quality Checklist

Before ending your session, verify:

- [ ] All research findings stored in `research_reports` table
- [ ] Entities discovered during this session have files in `.memory/entities/`
- [ ] Entity registry rows exist for all new entity files
- [ ] Domain-specific tables updated (content_ideas, tickets, etc. if applicable)
- [ ] Metrics stored in `metrics` table (or domain-specific metrics table)
- [ ] Downstream agents notified of new data
- [ ] No valuable data left only in `scratch/` or `~/Documents/`
