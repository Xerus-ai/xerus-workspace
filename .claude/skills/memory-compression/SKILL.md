---
name: memory-compression
description: Compress old activity entries in .memory/ entity files to keep memory lean. Scans for Activity/Episodic sections exceeding a threshold, LLM-summarizes old entries by quarter, archives raw data, and commits. Use when running monthly maintenance, memory files grow large, or asked to "compress memory" or "archive old activity".
user-invocable: false
allowed-tools: Read, Glob, Grep, Edit, Bash(cd .memory && git *)
---

# Memory Compression (DRM)

Compress old activity/episodic entries in .memory/ to prevent unbounded growth. Full history available via git log.

## Configuration

- ENTRY_THRESHOLD: 15 (compress when section has >15 entries)
- KEEP_RECENT_DAYS: 30 (keep entries from last 30 days uncompressed)

## Procedure

1. Scan memory files for large Activity/Episodic sections:
   - Glob .memory/agents/**/*.md
   - Glob .memory/projects/**/channel.md
   - Glob .memory/projects/**/project.md
   - Look for ## Activity or ## Episodic sections with >ENTRY_THRESHOLD list items (- YYYY-MM-DD: ...)

2. Partition entries by date:
   - Recent: within last KEEP_RECENT_DAYS (keep as-is)
   - Old: older than KEEP_RECENT_DAYS (candidates for compression)
   - Skip file if fewer than ENTRY_THRESHOLD old entries

3. Group old entries by calendar quarter (Q1=Jan-Mar, Q2=Apr-Jun, Q3=Jul-Sep, Q4=Oct-Dec).

4. Summarize each quarter in 2-3 sentences. Preserve key decisions, metrics, relationship changes, milestones. Format as:
   ```
   ### Q{N} {YEAR} Summary
   {2-3 sentence summary}
   ```

5. Archive raw entries to .memory/archive/{entity-type}/{entity-name}/Q{N}-{YEAR}.md with header:
   ```
   # Q{N} {YEAR} Archive - {entity-type}/{entity-name}
   Archived from: {source-path}
   Archived on: {date}
   ## Raw Entries
   {original entries}
   ```

6. Replace old entries in source file with quarter summaries. Keep recent entries under "## Recent Activity".

7. Git commit:
   ```bash
   cd .memory && git add -A && git commit -m "compress:{entity-type}/{entity-name}: Archived N entries from {quarters}"
   ```

8. Print summary: files scanned, files compressed, entries archived, quarters summarized.
