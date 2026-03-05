---
name: knowledge-graph-maintenance
description: Maintain bidirectional backlink consistency in the .memory/ knowledge graph. Scans entity and topic files for [[wiki]] references, detects missing reverse links, and fixes them. Use when running weekly maintenance, asked to "fix backlinks" or "check memory consistency", or after bulk memory writes.
user-invocable: false
allowed-tools: Read, Glob, Grep, Edit, Bash(cd .memory && git *)
---

# Knowledge Graph Maintenance

Maintain bidirectional [[wiki-link]] consistency across .memory/ files.

## Procedure

1. Scan all memory files:
   - Glob .memory/agents/**/*.md
   - Glob .memory/projects/**/*.md
   - Glob .memory/shared/*.md
   - Glob .memory/workspace.md

2. Extract [[path/name]] references from each file using regex \[\[([^\]]+)\]\].

3. Resolve references to file paths:
   - [[agents/slug]] -> .memory/agents/slug/semantic.md
   - [[projects/slug]] -> .memory/projects/slug/project.md
   - [[shared/name]] -> .memory/shared/name.md
   - [[workspace]] -> .memory/workspace.md
   - [[agents/slug/file]] -> .memory/agents/slug/file.md

4. For each reference A -> B:
   - Verify target file B exists
   - If B exists, check B contains a reference back to A
   - If reverse link missing, append to B's "## Connected To" section:
     `- [[source/path]] - (auto-linked by maintenance)`

5. Track orphaned references (target file does not exist). Do not create missing files.

6. Git commit:
   ```bash
   cd .memory && git add -A && git commit -m "maintenance:knowledge-graph: Fixed N backlinks, M orphaned refs"
   ```

7. Print summary: files scanned, references found, backlinks fixed, orphaned refs.
