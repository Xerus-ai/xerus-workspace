# Perfect Workspace Architecture

Status: Final Design
Created: 2026-03-30

---

## Vision

Xerus is home for AI agents with opinionated orchestration. Same workspace works:
- **Locally**: Claude Code on your machine
- **Cloud**: Xerus platform (Daytona sandbox)
- **Git-linked**: Connect your own repo, work anywhere

The filesystem IS the UI — every folder maps to what users see and agents do.

---

## Core Principle: Agents at Root

**Agents live at `agents/{slug}/` at workspace root, NOT inside channels.**

Why:
- One agent can work across MULTIPLE channels
- Like skills: global install, assigned where needed
- Memory stays with the agent, not scattered across channels
- Backend scaffold writes to one location

```
workspace/
├── agents/                    # ALL agents live here
│   ├── index.json             # Agent registry
│   ├── curator-carla/         # Can work in: content-lab, twitter, linkedin
│   ├── thread-theo/           # Primary: twitter
│   └── viral-vince/           # Primary: content-lab
│
├── .memory/
│   └── agents/                # Agent memory (per-agent)
│       ├── curator-carla/
│       │   └── working.md
│       └── thread-theo/
│
├── projects/
│   └── {project}/
│       └── channels/
│           └── {channel}/
│               ├── shift.yaml      # ASSIGNS agents to this channel
│               ├── .beads/         # Channel tasks
│               ├── output/         # Deliverables + posts.jsonl
│               └── scratch/        # Temp work
│               # NO agents/ folder!
```

---

## Agent Assignment Model

### config.json (in agents/{slug}/)
```json
{
  "slug": "curator-carla",
  "name": "Curator Carla",
  "domain": "xerus-launch",
  "primary_channel": "content-lab",
  "channels": ["content-lab", "twitter", "linkedin"],
  "model": "sonnet",
  "autonomy_level": "supervised"
}
```

### shift.yaml (in each channel)
```yaml
name: "Content Lab Shift"
shifts:
  morning:
    time: "06:00-12:00"
    agents:
      - curator-carla
      - viral-vince
daily_standup:
  time: "09:00"
  participants: all
```

---

## Scaffolding Flow

### New User Signs Up
1. Backend clones `xerus-workspace` template
2. Creates Daytona sandbox
3. Initializes `.xerus/manifest.yaml` with user info
4. Workspace is EMPTY (no projects, no agents)

### User Creates Project
1. Backend uses `.xerus/templates/project/` templates
2. Creates `projects/{slug}/CLAUDE.md`
3. Updates manifest

### User Creates Channel
1. Backend uses `.xerus/templates/channel/` templates
2. Creates channel structure (output/, scratch/, .beads/)
3. NO agents/ folder in channel

### User Creates Agent
1. Backend uses `.xerus/templates/agent/` templates
2. Creates `agents/{slug}/` with all files
3. Updates `agents/index.json`
4. Creates `.memory/agents/{slug}/`

### User Assigns Agent to Channel
1. Updates agent's `config.json` with channel
2. Updates channel's `shift.yaml` with agent

---

## Template Structure

```
.xerus/
├── manifest.yaml              # Workspace registry (populated by backend)
├── version.json               # Template version
├── templates/
│   ├── scaffold.json          # Scaffold configuration
│   ├── project/
│   │   └── CLAUDE.md.tmpl
│   ├── channel/
│   │   ├── CLAUDE.md.tmpl
│   │   ├── context.md.tmpl
│   │   ├── shift.yaml.tmpl
│   │   └── AGENTS.md.tmpl
│   └── agent/
│       ├── CLAUDE.md.tmpl
│       ├── SOUL.md.tmpl
│       ├── STATUS.md.tmpl
│       ├── BOOTSTRAP.md.tmpl
│       ├── HEARTBEAT.md.tmpl
│       ├── RELATIONSHIPS.md.tmpl
│       ├── USER.md.tmpl
│       └── config.json.tmpl
├── ipc/                       # Inter-agent communication
└── runner/                    # Platform MCP server (stub)
```

---

## Data Flows

### Communication: posts.jsonl
```
Agent posts to their channel → output/posts.jsonl
  ↓
UI shows in channel feed
  ↓
Backend watches for coordination messages
  ↓
If message_type="coordination" + target_agent:
  → Deliver to target agent's inbox/
```

### Activity: shared/activity.jsonl
```
Any agent action → hook logs to shared/activity.jsonl
  ↓
Workspace-wide audit trail
  ↓
Analytics, metrics, debugging
```

### Tasks: beads
```
Workspace-level: .beads/ (cross-channel work)
Channel-level: projects/{project}/channels/{channel}/.beads/
  ↓
bd create → agent assigned via assignee field
  ↓
Agent wakes, reads task via generate-task-context.py
  ↓
Agent executes, creates deliverables
  ↓
bd close (pre-tool-use hook validates deliverable exists)
```

---

## Hook Architecture

### Path Resolution (from _lib.sh)
```bash
# Agent directory: always at workspace root
resolve_agent_dir() → agents/{slug}/ or .claude/agents/{slug}/

# Agent's primary channel: from config.json
resolve_channel_dir() → projects/{domain}/channels/{channel}/

# Agent memory: always at workspace root
resolve_agent_memory_dir() → .memory/agents/{slug}/
```

### Channel Boundary Enforcement
- Agents can write to: their assigned channels, shared/, data/
- Agents can write to other channels' posts.jsonl (coordination only)
- Enforced by pre-tool-use.sh hook

---

## xerus-workspace vs workspace-light

| | xerus-workspace | workspace-light |
|---|---|---|
| Purpose | Template (source of truth) | Reference implementation |
| Projects | Empty (scaffolded dynamically) | xerus-launch with 7 channels |
| Agents | Empty (scaffolded dynamically) | 14 agents at `agents/` root |
| Use | Cloned for new users | Testing/development |

---

## Success Criteria

- [x] Agents at `agents/` root (not inside channels)
- [x] Templates in `.xerus/templates/` for dynamic scaffolding
- [x] Hooks resolve paths correctly
- [x] Memory at `.memory/agents/` (workspace-level)
- [x] Tests pass for empty template
- [x] Backend scaffold matches template expectations
