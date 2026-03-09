---
name: sanitize-workspace
description: Validate and repair workspace structure after restore, import, or template upgrade. Fixes CLAUDE.md path references, ensures directory layout matches expected structure, removes dangerous files (symlinks, path traversal artifacts), validates agent configs as valid JSON, checks .memory/ git repo integrity, and re-links platform files. Use when restoring from S3 backup, importing a user-uploaded workspace archive, upgrading workspace template version, or asked to "sanitize workspace" or "validate workspace".
user-invocable: false
allowed-tools: Read, Write, Glob, Grep, Edit, Bash(ls *), Bash(find *), Bash(rm *), Bash(cd .memory && git *), Bash(test *), Bash(readlink *), Bash(stat *)
---

# Sanitize Workspace

Validate and repair workspace structure after restore, import, or template upgrade.
Run all checks, fix what can be auto-fixed, report what requires manual action.

## Expected Workspace Structure

```
CLAUDE.md                              # Root workspace instructions (platform-owned)
README.md                              # Workspace readme
.xerus/version.json                    # Platform version tracking
.xerus/runner/                         # Agent runner (platform-owned, hidden)
.claude/skills/                        # Installed skills
.claude/settings.json                  # SDK settings
.claude/hooks/scripts/                 # Hook scripts
.mcp.json                              # MCP server config
.memory/                               # Git-tracked memory repo
.memory/index.md                       # Memory entity index
.memory/user/preferences.md            # User preferences
.memory/agents/                        # Per-agent memory
.memory/projects/                      # Per-project memory
.memory/shared/                        # Shared memory
.memory/entities/                      # Named entities
.memory/topics/                        # Topic files
.memory/company/                       # Company-level memory
.memory/archive/                       # Compressed memory archives
.beads/issues.jsonl                    # Task tracker
agents/index.json                      # Agent registry
agents/xerus-master/                   # Master agent (platform-owned)
agents/xerus-master/config.json        # Must be valid JSON
projects/                              # User projects
shared/knowledge/                      # Shared knowledge base
shared/inbox/                          # Cross-team messages
shared/activity.jsonl                  # Execution log
data/                                  # Structured data
marketplace/                           # Read-only skill/agent catalog
```

## Procedure

### Phase 1: Safety Checks

1. Find and remove dangerous files:
   ```bash
   # Find symlinks pointing outside workspace
   find . -type l -exec readlink -f {} \; 2>/dev/null
   ```
   - Delete any symlink whose target resolves outside the workspace root
   - Delete any file with `..` in its name or path components
   - Delete any file with null bytes or control characters in the name
   - Log each removal

2. Check for path traversal artifacts:
   - Glob for files matching `**/../*` or `**/./*`
   - Remove if found

### Phase 2: Structure Validation

3. Verify required directories exist (create missing ones):
   - `.xerus/`, `.xerus/runner/`
   - `.claude/`, `.claude/skills/`, `.claude/hooks/scripts/`, `.claude/rules/`
   - `.memory/`, `.memory/agents/`, `.memory/projects/`, `.memory/shared/`,
     `.memory/entities/`, `.memory/topics/`, `.memory/company/`, `.memory/archive/`,
     `.memory/user/`
   - `.beads/`
   - `agents/`, `agents/xerus-master/`
   - `projects/`, `shared/`, `shared/knowledge/`, `shared/inbox/`
   - `data/`, `marketplace/`

4. Verify required files exist (report missing, do not fabricate content):
   - `CLAUDE.md` -- if missing, flag as CRITICAL (platform must re-provision)
   - `.xerus/version.json` -- if missing, flag as CRITICAL
   - `.mcp.json` -- if missing, flag as WARNING
   - `agents/index.json` -- if missing, create empty: `{"agents":[]}`
   - `.memory/index.md` -- if missing, create with header: `# Memory Index\n`
   - `.beads/issues.jsonl` -- if missing, create empty file
   - `shared/activity.jsonl` -- if missing, create empty file

### Phase 3: Agent Validation

5. Read `agents/index.json`:
   - Validate it is valid JSON
   - If malformed, attempt to fix (remove trailing commas, fix quotes)
   - If unrecoverable, rename to `agents/index.json.corrupt` and create fresh

6. For each agent slug listed in index.json:
   - Verify `agents/{slug}/config.json` exists and is valid JSON
   - Verify `agents/{slug}/SOUL.md` exists
   - Verify `agents/{slug}/STATUS.md` exists
   - If config.json is invalid JSON, rename to `.corrupt` and report
   - Flag missing soul files but do not generate them (use agent-creation skill for that)

7. Scan `agents/` for directories not listed in index.json:
   - If directory has config.json, add to index.json
   - If directory is empty or has no config.json, report as orphaned

### Phase 4: Memory Integrity

8. Check `.memory/` git repo:
   ```bash
   cd .memory && git status
   ```
   - If not a git repo, initialize: `cd .memory && git init && git add -A && git commit -m "init: workspace sanitize"`
   - If has uncommitted changes, commit: `cd .memory && git add -A && git commit -m "sanitize: commit uncommitted memory changes"`
   - If git is corrupted, report as CRITICAL

9. Verify `.memory/user/preferences.md` exists (create stub if missing):
   ```markdown
   # User Preferences
   (No preferences recorded yet)
   ```

### Phase 5: Path Correction

10. Read `CLAUDE.md` and verify internal path references are correct:
    - All paths mentioned in the Workspace Layout section should resolve to existing directories
    - If a referenced path does not exist, create the directory
    - Do NOT modify CLAUDE.md content (it is platform-owned)

11. For each agent, read `agents/{slug}/CLAUDE.md` (if exists):
    - Verify paths like `.memory/agents/{slug}/` resolve correctly
    - Fix any hardcoded wrong paths

### Phase 6: Report

12. Print structured summary:
    ```
    === Workspace Sanitize Report ===
    Dangerous files removed: N
    Directories created: N
    Missing critical files: [list]
    Agent configs validated: N/N
    Agent configs corrupted: [list]
    Orphaned agent dirs: [list]
    Memory repo status: OK | initialized | committed | CORRUPTED
    Path references fixed: N

    Status: CLEAN | WARNINGS | CRITICAL
    ```

## Rules

- Never delete user data (agents/, projects/, .memory/ content, shared/)
- Never modify CLAUDE.md content (platform-owned, only verify it exists)
- Never fabricate agent soul files -- flag missing and suggest running agent-creation skill
- Always commit .memory/ changes with descriptive messages
- Rename corrupted files to .corrupt instead of deleting
