# Workspace Architecture v2

**Date**: 2026-03-29
**Status**: Design
**Goal**: Align filesystem structure with UI hierarchy (Workspace → Projects → Channels) and enable proper agent orchestration within channels.

---

## Problem Statement

### Current Issues

1. **Agents at wrong level**: `agents/` folder is at workspace root, but UI shows agents scoped to channels
2. **Memory fragmentation**: `.memory/` is workspace-level only, not hierarchical per channel
3. **No channel state management**: Missing standup orchestration, shift management, metrics tracking
4. **Hierarchy not enforced**: Nothing stops an agent from accessing another channel's data
5. **Orchestration gaps**: Hooks exist but don't enforce the Workspace→Project→Channel→Agent hierarchy

### UI Hierarchy (Target)

```
Workspace
└── Projects (multiple per workspace)
    └── Channels (multiple per project)
        ├── Goal (channel mission)
        ├── Tasks (channel-level .beads/)
        ├── Deliverables (channel output)
        └── Agents (scoped to channel, interact via posts.jsonl, have daily standups)
```

---

## Architecture Design

### Directory Structure

```
workspace/
├── CLAUDE.md                    # Workspace-level instructions (SOPs)
├── .xerus/
│   ├── config.yaml              # Workspace config (name, version)
│   ├── manifest.yaml            # Registry: all projects/channels/agents
│   └── state/
│       └── orchestration.yaml   # Global orchestration rules
│
├── .claude/
│   ├── settings.json            # Claude Code settings + hooks
│   ├── hooks/scripts/           # Hook implementations
│   ├── skills/                  # Workspace-level skills
│   ├── commands/                # Workspace-level commands
│   └── agents/                  # WORKSPACE-LEVEL agents only (xerus-master, etc.)
│
├── .memory/
│   ├── index.md                 # Knowledge graph index
│   ├── entities/                # Shared entity knowledge
│   ├── user/                    # User preferences
│   └── workspace/               # Workspace-level working memory
│
├── shared/
│   ├── knowledge/
│   │   └── company.md           # Vision, mission, values, goals
│   ├── office/                  # Templates
│   ├── standup/                 # Daily workspace-wide standup summaries
│   └── activity.jsonl           # Global activity log
│
├── data/
│   ├── company.db               # Shared SQLite
│   └── drive/                   # Shared files
│
├── marketplace/                 # Read-only agent/skill catalogs (submodule)
│
└── projects/
    └── {project-slug}/
        ├── CLAUDE.md            # Project mission, OKRs, channel list
        ├── .project/
        │   ├── config.yaml      # Project settings
        │   └── state/           # Project-level state
        │
        └── channels/
            └── {channel-slug}/
                ├── CLAUDE.md           # Channel mission, goals, metrics, TEAM ROSTER
                ├── context.md          # Dynamic channel context
                ├── shift.yaml          # Shift schedule (who works when)
                │
                ├── .channel/
                │   ├── config.yaml     # Channel settings
                │   └── state/
                │       ├── standups/   # Daily standup logs (YYYY-MM-DD.md)
                │       ├── handoffs/   # Agent handoff records
                │       └── metrics/    # Goal progress tracking
                │
                ├── .beads/             # Channel-level task tracking
                │
                ├── agents/             # CHANNEL-SCOPED AGENTS
                │   └── {agent-slug}/
                │       ├── CLAUDE.md       # Agent config (skills, knowledge, context refs)
                │       ├── SOUL.md         # Personality, values, communication style
                │       ├── STATUS.md       # Current state (mood, energy, active task)
                │       ├── BOOTSTRAP.md    # First-run onboarding checklist
                │       ├── HEARTBEAT.md    # Self-prompted behaviors
                │       ├── RELATIONSHIPS.md # Teammate rapport notes
                │       ├── USER.md         # Learned user preferences
                │       ├── inbox/          # Incoming coordination messages
                │       └── knowledge/      # Agent-specific knowledge docs
                │
                ├── .memory/            # CHANNEL-LEVEL AGENT MEMORY
                │   └── agents/
                │       └── {agent-slug}/
                │           ├── working.md      # Active working state
                │           ├── expertise.md    # Learned expertise
                │           └── .task-context.md # Generated task context
                │
                ├── scratch/            # Temporary work (disposable)
                └── output/
                    ├── deliverables/   # Final outputs (persistent)
                    └── posts.jsonl     # Channel communication feed
```

### Key Design Decisions

#### 1. Agents Scoped to Channels

**Before**: All agents in workspace-root `agents/` folder
**After**: Agents live in `projects/{project}/channels/{channel}/agents/{agent}/`

**Why**:
- Matches UI hierarchy exactly
- Enforces natural boundaries
- Each channel is a "team" with its own agents
- Agent memory is co-located with agent definition

**Exception**: Workspace-level agents (like `xerus-master`) that operate across all channels stay in `.claude/agents/`

#### 2. Hierarchical Memory

**Before**: Single `.memory/` at workspace root
**After**: Memory at each level

```
workspace/.memory/              # Shared entities, user preferences
└── projects/{p}/channels/{c}/.memory/
    └── agents/{a}/
        ├── working.md          # Agent's current state
        ├── expertise.md        # Agent's learned capabilities
        └── .task-context.md    # Generated by hooks
```

**Why**:
- Agent state stays with agent
- Channel can be archived/moved independently
- Clearer ownership and isolation

#### 3. Channel State Management

New `.channel/state/` directory for orchestration state:

```yaml
# .channel/state/standups/2026-03-29.md
# Daily Standup - 2026-03-29

## Curator Carla
- **Yesterday**: Researched 8 trends, flagged 3 high-urgency
- **Today**: Competitor analysis on Manus launch
- **Blockers**: None

## Viral Vince
- **Yesterday**: Generated 5 content ideas from trends
- **Today**: Ideas for Manus competitor thread
- **Blockers**: Waiting on trend report from Carla
```

```yaml
# .channel/state/handoffs/2026-03-29-carla-to-vince.yaml
from: curator-carla
to: viral-vince
timestamp: 2026-03-29T10:30:00Z
context: "Completed trend research, 3 high-urgency trends ready"
deliverables:
  - output/deliverables/trends-2026-03-29.md
tasks_for_recipient:
  - Generate content ideas from trends
```

#### 4. Manifest File

`.xerus/manifest.yaml` provides a quick registry:

```yaml
# .xerus/manifest.yaml
workspace:
  name: "Xerus Marketing"
  version: "2.0.0"

projects:
  xerus-launch:
    path: projects/xerus-launch
    channels:
      content-lab:
        path: projects/xerus-launch/channels/content-lab
        agents: [curator-carla, viral-vince]
      twitter:
        path: projects/xerus-launch/channels/twitter
        agents: [trend-tara, thread-theo, reply-rex]
      # ... etc

workspace_agents:  # Agents that operate across channels
  - xerus-master
  - xerus-cto
```

**Why**: Fast lookup for orchestration without scanning filesystem

#### 5. Shift Management

`shift.yaml` at channel level defines scheduling:

```yaml
# projects/xerus-launch/channels/content-lab/shift.yaml
timezone: "America/Los_Angeles"

shifts:
  morning:
    time: "06:00-12:00"
    agents:
      - curator-carla   # Research trends

  afternoon:
    time: "12:00-18:00"
    agents:
      - viral-vince     # Generate ideas from morning research

  evening:
    time: "18:00-22:00"
    agents:
      - curator-carla   # Evening trend scan

daily_standup:
  time: "09:00"
  participants: all
  output: .channel/state/standups/{date}.md
```

---

## Orchestration Layer

### Hook Responsibilities

| Hook | Purpose | Key Actions |
|------|---------|-------------|
| `SessionStart` | Initialize agent session | 1. Resolve agent→channel mapping<br>2. Inject channel CLAUDE.md<br>3. Generate task context from channel .beads/<br>4. Check shift schedule<br>5. Read channel context.md |
| `UserPromptSubmit` | Validate and augment prompt | 1. Inject current time/date<br>2. Check if standup time |
| `PreToolUse` | Enforce boundaries | 1. Validate writes are within channel scope<br>2. Block access to other channels' data |
| `PostToolUse` | Track and propagate | 1. Log activity to channel<br>2. Check task completion<br>3. Trigger downstream notifications |
| `TeammateIdle` | Coordinate handoffs | 1. Update STATUS.md<br>2. Write handoff record<br>3. Notify next agent in shift |
| `TaskCompleted` | Cascade dependencies | 1. Notify dependent agents<br>2. Update channel metrics<br>3. Check if shift should rotate |
| `SessionEnd` | Save state | 1. Update working.md<br>2. Write session summary<br>3. Update STATUS.md |
| `PreCompact` | Preserve state | 1. Force-save working.md |

### Commands

| Command | Purpose | Actions |
|---------|---------|---------|
| `/standup` | Daily channel standup | Collect status from all channel agents, write standup summary |
| `/handoff {to-agent}` | Hand off work | Write handoff record, notify target agent |
| `/shift` | Manage shift schedule | View/edit shift.yaml, rotate shifts |
| `/status` | Channel status | Show all agents' current STATUS.md |
| `/goals` | Goal hierarchy | Show channel goals → project OKRs → company vision |
| `/metrics` | Channel metrics | Show goal progress from .channel/state/metrics/ |

### Skills

| Skill | Purpose | Used By |
|-------|---------|---------|
| `channel-orchestrator` | Channel-level coordination | Channel manager agent |
| `standup-runner` | Run daily standups | /standup command |
| `handoff-manager` | Manage agent handoffs | /handoff command |
| `goal-tracker` | Track OKR progress | /metrics command |
| `shift-scheduler` | Manage shift rotation | /shift command |

---

## Agent Scoping Rules

### Boundary Enforcement

Agents are restricted to their channel scope:

```
ALLOWED for agent in projects/p1/channels/c1/agents/agent1/:
  ✓ projects/p1/channels/c1/scratch/*
  ✓ projects/p1/channels/c1/output/*
  ✓ projects/p1/channels/c1/.memory/agents/agent1/*
  ✓ projects/p1/channels/c1/context.md (read)
  ✓ projects/p1/channels/c1/CLAUDE.md (read)
  ✓ shared/knowledge/* (read)
  ✓ .memory/entities/* (read/write for entities)
  ✓ data/company.db (read/write via SQL)

DENIED:
  ✗ projects/p1/channels/c2/* (other channel)
  ✗ projects/p2/* (other project)
  ✗ agents/* (workspace-root agents folder - deprecated)
  ✗ Other agents' memory directories
```

### Cross-Channel Communication

Agents communicate across channels via coordination messages:

```json
// Agent in channel c1 writes to c2's output/posts.jsonl
{
  "agent_slug": "curator-carla",
  "source_channel": "content-lab",
  "content": "High-urgency trend: AI coding tools. See deliverables/trends-2026-03-29.md",
  "message_type": "coordination",
  "metadata": {
    "target_channel": "twitter",
    "target_agent": "trend-tara"
  },
  "posted_at": "2026-03-29T10:30:00Z"
}
```

The `channel-watcher` service (backend) routes these to target agent inboxes.

---

## Migration Path

### Phase 1: Structure Update

1. Create new directory structure in `xerus-workspace/`
2. Move agents from `agents/` to their channels
3. Create `.channel/` state directories
4. Create manifest file

### Phase 2: Memory Migration

1. Move `.memory/agents/{slug}/` to `projects/*/channels/*/agents/{slug}/.memory/`
2. Update all path references in hooks

### Phase 3: Hook Updates

1. Update `session-start.sh` to resolve channel from agent path
2. Add `pre-tool-use.sh` boundary enforcement
3. Update `generate-task-context.py` for new paths

### Phase 4: Command/Skill Creation

1. Create `/standup`, `/handoff`, `/shift` commands
2. Create `channel-orchestrator` skill

---

## Success Criteria

1. **Hierarchy Match**: Filesystem exactly mirrors UI (Workspace→Projects→Channels→Agents)
2. **Agent Isolation**: Agents can only access their channel's data + shared resources
3. **Standup Works**: `/standup` collects status from all channel agents automatically
4. **Handoffs Work**: Agents can hand off work with context preserved
5. **Goals Trace**: Every task traces to channel goal → project OKR → company goal
6. **Shift Rotation**: Agents activate based on shift schedule
7. **Tests Pass**: All workspace validation tests pass

---

## Appendix: File Templates

### Channel CLAUDE.md Template

```markdown
# Channel: {channel-name}

## Mission
{one-line mission statement}

## Team
{list agents with roles}

## Goals & Metrics
| Metric | 30-Day | 90-Day |
|--------|--------|--------|
| ... | ... | ... |

## Daily Output
{what this channel produces daily}

## Rules
{channel-specific rules}

## Cross-Channel
{how this channel interacts with others}
```

### Agent CLAUDE.md Template (Channel-Scoped)

```markdown
# Agent: {agent-name}

## Identity
Read SOUL.md for personality and values.

## Channel
Primary: {path to channel}

## Colleagues
{list other agents in channel}

## Skills
| Skill | Use For |
|-------|---------|
| ... | ... |

## Knowledge
{list knowledge files}

## Context
- .memory/agents/{slug}/working.md
- ../context.md (channel context)

## Output
- scratch/ (temporary)
- output/deliverables/ (final)
- output/posts.jsonl (communication)

## Autonomy
Level: {supervised|semi-autonomous|autonomous}
```

### shift.yaml Template

```yaml
timezone: "UTC"

shifts:
  default:
    time: "00:00-23:59"
    agents: []  # All agents active

daily_standup:
  time: "09:00"
  participants: all
  output: .channel/state/standups/{date}.md

handoff_protocol:
  require_summary: true
  notify_recipient: true
```
