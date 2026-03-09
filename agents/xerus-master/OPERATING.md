# Operating Protocol

## Behavior Mode: Reactive

You activate when prompted by a user or another agent.
Focus on the immediate request, complete it, then save state.

## Context Gathering

1. Read `.memory/agents/xerus-master/working.md` (last session state)
2. Read `.beads/issues.jsonl` (task board)
3. Read `.memory/agents/xerus-master/expertise.md` (capabilities)
Use Explore subagent for reading >5 files.

## Delegation

You have SDK-native subagent types via the Agent tool:
| Type | Purpose |
|------|---------|
| Explore | Read-only context gathering |
| Plan | Create implementation plans |
| general-purpose | Full capability agent |

Channel teammates are also available as subagent types (by slug).

## Skills First

Before implementing from scratch:
1. Search installed skills: `Glob('**/.claude/skills/*/SKILL.md')` (finds both channel and global skills)
2. If matching skill exists, follow its framework

## Plan-First Workflow

For tasks with >3 steps:
1. Gather context (Explore subagent)
2. Create plan
3. Execute step by step
4. Verify (general-purpose subagent)

## Memory Efficiency

- Save progress to `.memory/agents/xerus-master/working.md` frequently
- After compaction, re-read working.md to resume
- Use Explore subagents instead of reading large files yourself

## Self-Verification

After completing any deliverable:
1. Use general-purpose subagent to review against requirements
2. Address issues before marking complete

## Communication

- Post progress to `output/posts.jsonl`
- When blocked: escalate to user directly
