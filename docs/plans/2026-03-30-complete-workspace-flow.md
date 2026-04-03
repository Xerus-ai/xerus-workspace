# Complete Workspace Flow

## The Big Picture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           XERUS PLATFORM                                     │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌──────────────┐     ┌──────────────┐     ┌──────────────┐                │
│  │ xerus-agents │     │xerus-skills  │     │xerus-workspace│                │
│  │ (marketplace)│     │ (marketplace)│     │  (template)   │                │
│  └──────┬───────┘     └──────┬───────┘     └──────┬───────┘                │
│         │                    │                    │                         │
│         │    User signs up   │                    │                         │
│         │         ↓          │                    ↓                         │
│         │    ┌───────────────────────────────────────┐                     │
│         │    │         USER'S WORKSPACE              │                     │
│         │    │      (Daytona sandbox OR local)       │                     │
│         │    └───────────────────────────────────────┘                     │
│         │                    ↑                    ↑                         │
│         └────────────────────┴────────────────────┘                         │
│              Install agents        Install skills                           │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 1. Marketplace Structure

### xerus-agents/ (Agent Marketplace)
```
xerus-agents/
├── content/
│   ├── curator-carla/
│   │   ├── config.json      # Metadata (no channel assignment)
│   │   └── agent.md         # Full agent definition
│   └── wordsmith-wally/
├── marketing/
│   ├── buzz-betty/
│   └── inbox-izzy/
├── research/
│   └── maven-max/
├── data/
│   └── datadog-dan/
└── sales/
    └── ...
```

### Agent Definition (in marketplace)
```json
// config.json
{
  "slug": "curator-carla",
  "name": "Curator Carla",
  "description": "Content curation specialist...",
  "role": "creative",
  "model": "claude-sonnet-4.5",
  "autonomy_level": "supervised",
  "domain": "",                    // Empty - set on install
  "primary_channel": "",           // Empty - set on install
  "channels": [],                  // Empty - set on install
  "tools": ["firecrawl", "reddit"],
  "skills": ["data-steward", "gws-sheets"]
}
```

---

## 2. User's Workspace (after install)

```
workspace/
│
├── agents/                        # ALL AGENTS HERE
│   ├── index.json                 # Agent registry
│   │
│   ├── curator-carla/             # Installed from marketplace
│   │   ├── config.json            # Now has channel assignments!
│   │   ├── CLAUDE.md              # Generated from agent.md
│   │   ├── SOUL.md                # Generated
│   │   ├── STATUS.md              # Runtime state
│   │   ├── BOOTSTRAP.md           # First-run checklist
│   │   ├── HEARTBEAT.md           # Scheduled tasks
│   │   ├── RELATIONSHIPS.md       # Team dynamics
│   │   ├── USER.md                # Learned preferences
│   │   ├── OPERATING.md           # Operating procedures
│   │   ├── inbox/                 # Received messages
│   │   │   └── processed/
│   │   ├── knowledge/             # Agent-specific docs
│   │   └── playbooks/             # Agent playbooks
│   │
│   └── thread-theo/               # Another installed agent
│       └── ...
│
├── .memory/
│   └── agents/                    # Per-agent memory
│       ├── curator-carla/
│       │   ├── working.md         # Current work state
│       │   ├── expertise.md       # Learned skills
│       │   └── .task-context.md   # Current assignment (generated)
│       └── thread-theo/
│
├── projects/
│   └── my-startup/                # User-created project
│       ├── CLAUDE.md              # Project mission, OKRs
│       └── channels/
│           │
│           ├── content-lab/       # User-created channel
│           │   ├── CLAUDE.md      # ← Channel mission, goals, team!
│           │   ├── context.md     # Dynamic state, metrics
│           │   ├── shift.yaml     # Agent assignments
│           │   ├── AGENTS.md      # Beads onboarding
│           │   ├── .beads/        # Channel tasks
│           │   │   └── issues.jsonl
│           │   ├── output/
│           │   │   ├── deliverables/
│           │   │   └── posts.jsonl
│           │   └── scratch/
│           │
│           └── twitter/           # Another channel
│               ├── CLAUDE.md      # Different mission/goals
│               ├── shift.yaml     # Different agent assignments
│               └── ...
│
├── .claude/
│   ├── agents/                    # ORCHESTRATORS only
│   │   ├── xerus-master/
│   │   └── xerus-cto/
│   ├── skills/                    # Global skills
│   └── hooks/                     # Orchestration
│
├── shared/
│   ├── knowledge/
│   │   └── company.md             # Vision, mission, goals
│   ├── activity.jsonl             # All agent activity
│   └── standup/                   # Daily summaries
│
└── .xerus/
    ├── manifest.yaml              # Complete workspace registry
    └── templates/                 # For scaffolding new items
```

---

## 3. Channel CLAUDE.md (The Important Part!)

```markdown
# Channel: Twitter

## Mission
Acquire paid beta users through competitor engagement and dogfooding proof.
Primary acquisition channel for Xerus.

## Team
- **Thread Theo** (lead) — Brand voice, dogfooding narrator
- **Reply Rex** — Competitor thread hunter
- **Trend Tara** — AI news curator
- **Curator Carla** (cross-channel) — Feeds content ideas

## Daily Output
- 3 tweets from Thread Theo (dogfooding proof + viral takes)
- 10-15 replies from Reply Rex
- 2-3 AI news tweets from Trend Tara

## Goals & Metrics
| Metric | 30-Day Target | 90-Day Target |
|--------|--------------|--------------|
| Followers | 500 | 5,000 |
| Engagement rate | 2% | 3% |
| DMs/week | 5 | 15 |
| Paid signups/week | 2 | 10 |

## Rules
1. Never be salesy - provide value first
2. Match Twitter tone - punchy, direct
3. Max 1-2 emojis per tweet
4. All drafts to output/deliverables/ for review

## Skills
| Skill | Use For |
|-------|---------|
| twitter-engagement | Content mix, engagement playbook |
| bird | Post tweets, search, mentions |
| data-steward | Persist metrics to company.db |

## Cross-Channel
- READ from content-lab for content ideas
- POST coordination to linkedin for repurposing
```

---

## 4. Agent Assignment Flow

### Step 1: User Installs Agent from Marketplace
```
xerus-agents/content/curator-carla/
    ↓ (backend copies)
workspace/agents/curator-carla/
```

### Step 2: Backend Updates agent's config.json
```json
{
  "slug": "curator-carla",
  "domain": "my-startup",
  "primary_channel": "content-lab",
  "channels": ["content-lab", "twitter", "linkedin"]  // Multi-channel!
}
```

### Step 3: Backend Updates channel's shift.yaml
```yaml
# content-lab/shift.yaml
shifts:
  morning:
    agents:
      - curator-carla  # Added!
      - viral-vince
```

### Step 4: Backend Updates channel's CLAUDE.md Team section
```markdown
## Team
- **Curator Carla** — Content curation, trend research  # Added!
- **Viral Vince** — Content ideation
```

### Step 5: Backend Updates manifest.yaml
```yaml
agents:
  curator-carla:
    path: agents/curator-carla
    channels: [content-lab, twitter, linkedin]

projects:
  my-startup:
    channels:
      content-lab:
        agents: [curator-carla, viral-vince]  # Updated!
```

---

## 5. How Agents Read Their Context

### On Wake (session-start.sh hook)
```
1. Read agents/{slug}/SOUL.md (who am I?)
2. Read agents/{slug}/STATUS.md (what's my state?)
3. Read .memory/agents/{slug}/.task-context.md (what's my task?)
4. Read .memory/agents/{slug}/working.md (what was I doing?)

Then based on config.json primary_channel:
5. Read projects/{domain}/channels/{channel}/CLAUDE.md (channel goals!)
6. Read projects/{domain}/channels/{channel}/context.md (current metrics)
7. Read shared/knowledge/company.md (company vision)
```

### Agent Knows:
- **Who they are**: SOUL.md, BOOTSTRAP.md
- **What to do**: .task-context.md (generated from beads)
- **Why it matters**: Channel CLAUDE.md goals → Project OKRs → Company vision
- **Who they work with**: Channel team roster
- **How to communicate**: posts.jsonl, coordination messages

---

## 6. Communication Flow

```
Curator Carla (content-lab) finds hot trend
    ↓
Posts to content-lab/output/posts.jsonl:
{
  "agent_slug": "curator-carla",
  "content": "Hot trend: AI coding assistants. 3 content ideas ready.",
  "message_type": "coordination",
  "metadata": {
    "target_agents": ["thread-theo", "post-paula"],
    "deliverable": "output/deliverables/trends-2026-03-30.md"
  }
}
    ↓
Backend delivers to:
  - agents/thread-theo/inbox/
  - agents/post-paula/inbox/
    ↓
Thread Theo wakes (heartbeat or manual)
    ↓
Reads inbox, sees coordination message
    ↓
Reads content-lab/output/deliverables/trends-2026-03-30.md
    ↓
Creates twitter/output/deliverables/tweets-2026-03-30.md
```

---

## 7. Goal Hierarchy Trace

```
shared/knowledge/company.md
│ "Build AI workforce platform, 10K users by Q4"
│
└── projects/my-startup/CLAUDE.md
    │ "O1: Acquire 100 paid beta users"
    │ "KR1: 5K Twitter followers"
    │
    └── channels/twitter/CLAUDE.md
        │ "Mission: Primary acquisition channel"
        │ "Goal: 500 followers in 30 days"
        │
        └── agents/thread-theo/
            │ Knows: My tweets serve the 500 follower goal
            │        which serves the 100 user OKR
            │        which serves the 10K user vision
            │
            └── Task: "Draft 3 dogfooding proof tweets"
                     Connected to channel goals!
```

---

## Summary

| Component | Location | Purpose |
|-----------|----------|---------|
| **Agent definitions** | `agents/{slug}/` | Who they are, config |
| **Agent memory** | `.memory/agents/{slug}/` | What they remember |
| **Channel work** | `projects/{proj}/channels/{ch}/` | Where work happens |
| **Channel goals** | `channels/{ch}/CLAUDE.md` | Why work matters |
| **Agent assignments** | `config.json` + `shift.yaml` | Who works where |
| **Communication** | `output/posts.jsonl` | How agents talk |
| **Tasks** | `.beads/issues.jsonl` | What to do |
| **Marketplace** | `xerus-agents/` | Where agents come from |
