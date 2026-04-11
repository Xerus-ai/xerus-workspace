---
name: workspace-sync
description: "Keep agent files in sync with their workspace environment. Update agent CLAUDE.md, BOOTSTRAP.md, HEARTBEAT.md, OPERATING.md, and channel CLAUDE.md when skills are installed or removed, knowledge docs change, or channel configs are updated. Use PROACTIVELY whenever: (1) skills are added or removed from .claude/skills/, (2) drive/ docs are created, modified, or deleted, (3) channel CLAUDE.md files change, (4) agents are added or removed, (5) user says 'sync agents', 'update agent files', 'refresh workspace', or (6) after any scaffolding operation that adds or removes capabilities."
---

# Workspace Sync

Reconcile agent files with current workspace state. Add new references, update changed ones, remove stale ones.

## Why This Exists

Agents only know what their files tell them. When skills are installed, knowledge changes, or channels reconfigure, agent files must reflect the current state — not yesterday's state.

## Process

### 1. Snapshot Current State

Build a complete picture of what exists right now:

```
# Skills
ls .claude/skills/*/SKILL.md -> list of installed skills with descriptions

# Knowledge
ls drive/*.md -> list of knowledge docs

# Channels + agents
Read agents/index.json -> agent-channel map
Read agents/*/config.json -> agent details (channels, primary_channel)

# What agents currently reference
Grep "\.claude/skills/" agents/*/CLAUDE.md -> skill refs per agent
Grep "drive/" agents/*/CLAUDE.md -> knowledge refs per agent
```

### 2. Detect Drift

Compare snapshot against what agents reference. Three categories:

| Status | Meaning | Action |
|--------|---------|--------|
| **Missing** | Workspace has it, agent does not | Add reference |
| **Stale** | Agent references it, workspace does not | Remove reference |
| **Changed** | Both have it, but content differs | Update reference |

### 3. Map Skills to Agents

Match skills to agents by analyzing SKILL.md scope and description:

| Scope | Target |
|-------|--------|
| `all-agents` | Every agent gets this skill |
| `channel-lead` | Only lead agents (first agent in channel team) |
| `system` | System-level, activated by hooks |
| Domain-specific keywords | Match to relevant channel agents |

When ambiguous, check if the skill's SKILL.md mentions specific agent roles or channel names.

### 4. Update Agent Files

For each affected agent, update in order. **Full reconciliation** — add, update, AND remove.

#### 4a. Agent CLAUDE.md (Module)

**Skills section:**
```markdown
## Skills
| Skill | Path | Use For |
|-------|------|---------|
| {name} | .claude/skills/{name}/SKILL.md | {1-line from description} |
```
- Add rows for newly installed skills mapped to this agent
- Remove rows for uninstalled skills (path no longer exists)
- Update description if skill SKILL.md changed

**Knowledge section:**
```markdown
## Knowledge
- drive/{doc}.md
```
- Add paths for new knowledge docs
- Remove paths for deleted knowledge docs

**Colleagues section:**
- Add new teammates if agents were added to same channel
- Remove teammates if agents were removed

#### 4b. Agent BOOTSTRAP.md

```markdown
- [ ] Read .claude/skills/{name}/SKILL.md
- [ ] Read drive/{doc}.md
```
- Add read tasks for new skills/knowledge
- Remove read tasks for deleted skills/knowledge

#### 4c. Agent HEARTBEAT.md

Only update if skills with explicit cadence were added or removed.

#### 4d. Channel CLAUDE.md

Update the `## Skills` table in channel CLAUDE.md:
- Add rows for newly installed channel-relevant skills
- Remove rows for uninstalled skills

### 5. Verify

After sync, validate all references resolve:

```bash
for slug in $(jq -r '.agents | keys[]' agents/index.json); do
  grep -oP '\.claude/skills/[^\s|]+|drive/[^\s]+' "agents/$slug/CLAUDE.md" | while read path; do
    test -e "$path" || echo "BROKEN: $slug -> $path"
  done
done
```

## Hook Integration

Triggered by PostToolUse hook when writes hit sync-relevant paths.
See `.claude/hooks/scripts/workspace-sync-hook.sh` for detection logic.
Hook writes sync requests to `.claude/sync-queue.jsonl`, skill reads queue on activation.

## Principles

- **True sync** — add, update, AND remove. Agent files reflect current state, not history.
- **Idempotent** — running twice produces the same result.
- **Minimal edits** — only touch files with actual drift. No unnecessary rewrites.
- **Channel-aware** — match skills to agents by scope. Not everything goes to everyone.
- **Never touch identity** — SOUL.md, STATUS.md, USER.md are agent-owned. Sync never modifies them.
