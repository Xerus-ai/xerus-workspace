---
name: housekeeping
description: Post-task workspace cleanup and health check. Clears temporary files, validates workspace cleanliness, checks .memory/ files are current, ACE reflections are up to date, knowledge indexes exist, shared/activity.jsonl is not bloated, and reports drift from expected workspace structure. Use after task completion, session end, or when asked to "clean up workspace", "run housekeeping", or "check workspace health".
user-invocable: false
allowed-tools: Read, Glob, Grep, Edit, Bash(ls *), Bash(find *), Bash(rm *), Bash(wc *), Bash(du *), Bash(cd .memory && git *), Bash(tail *), Bash(head *)
---

# Housekeeping

Post-task cleanup and workspace health validation.
Keep the workspace lean, organized, and consistent.

## Procedure

### Phase 1: Temp File Cleanup

1. Find and remove temporary/scratch files:
   - Glob `**/scratch/**` -- remove all contents (scratch is disposable between sessions)
   - Glob `**/*.tmp`, `**/*.bak`, `**/*.swp`, `**/.DS_Store`
   - Glob `**/tmp/**` in project channel directories
   - Do NOT remove files in `.memory/`, `agents/*/knowledge/`, or `shared/knowledge/`
   - Log each file removed

2. Check for oversized files (>10MB) that may be accidental:
   ```bash
   find . -type f -size +10M -not -path "./.git/*" -not -path "./marketplace/*" -not -path "./.xerus/*" -not -path "./node_modules/*"
   ```
   - Report any found (do not auto-delete -- may be legitimate knowledge base files)

### Phase 2: Activity Log Maintenance

3. Check `shared/activity.jsonl` size:
   ```bash
   wc -l shared/activity.jsonl
   ```
   - If >1000 lines: trim to last 500 lines, archive older entries to `shared/archive/activity-{date}.jsonl`
   - If file does not exist: create empty file

4. Check agent inbox directories for stale messages:
   - Glob `agents/*/inbox/*.json`
   - Messages older than 7 days with `"read": true` can be archived to `agents/{slug}/inbox/archive/`
   - Unread messages are never touched

### Phase 3: Memory Health

5. Check working memory currency for the agent that just ran:
   - Read `.memory/agents/{agent-slug}/working.md`
   - Verify it has been updated today (check for today's date or recent timestamps)
   - If stale (>24h since last update), flag as WARNING

6. Check `.memory/index.md` is not empty:
   - Read file, verify it has content beyond the header
   - If empty, scan `.memory/` for entity files and rebuild index

7. Verify `.memory/` has no uncommitted changes:
   ```bash
   cd .memory && git status --porcelain
   ```
   - If uncommitted changes exist: `cd .memory && git add -A && git commit -m "housekeeping: commit pending memory changes"`

### Phase 4: Agent State Validation

8. For each agent in `agents/index.json`:
   - Verify `agents/{slug}/STATUS.md` has a `## Current State` section
   - Check STATUS.md was updated within the last 3 sessions (grep for recent dates)
   - If STATUS.md is very stale, flag as INFO (agent may need bootstrap re-run)

9. Check ACE reflection currency:
   - Glob `.memory/agents/*/ace-*.md` or `.memory/agents/*/reflections.md`
   - If the agent that just ran has no reflections file, flag as INFO
   - If reflections file exists but has not been updated in >7 days, flag as WARNING

### Phase 5: Workspace Structure Drift

10. Quick structure check (subset of sanitize-workspace):
    - Verify `agents/index.json` is valid JSON
    - Verify `.xerus/version.json` exists
    - Verify `CLAUDE.md` exists
    - Verify `.mcp.json` exists
    - If any missing, flag as WARNING and suggest running sanitize-workspace

11. Check for orphaned output directories:
    - Glob `projects/*/channels/*/output/**`
    - If output directory has files older than 30 days, report total size
    - Do not auto-delete (user may want to keep deliverables)

12. Check project channel structure consistency:
    - For each project in `projects/`:
      - Verify `projects/{domain}/CLAUDE.md` exists
      - For each channel: verify `projects/{domain}/channels/{channel}/` has expected structure

### Phase 6: Report

13. Print structured summary:
    ```
    === Housekeeping Report ===
    Temp files cleaned: N
    Activity log: OK | trimmed (was N lines)
    Stale inbox messages archived: N
    Memory repo: clean | committed N changes
    Working memory: current | STALE (agent: slug)
    ACE reflections: current | STALE | missing
    Structure drift: none | [warnings]
    Oversized files: none | [list with sizes]
    Old output dirs: none | [list with sizes]

    Status: CLEAN | WARNINGS
    ```

## Rules

- Never delete files in `.memory/` (only commit uncommitted changes)
- Never delete files in `agents/*/knowledge/` or `shared/knowledge/`
- Never modify agent soul files (SOUL.md, system-prompt.md, etc.)
- Always archive before deleting (activity logs, inbox messages)
- scratch/ is always safe to clear entirely
- Output deliverables are never auto-deleted (report size only)
- Do not run if workspace is in CRITICAL state -- suggest sanitize-workspace first
