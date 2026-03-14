---
name: google-workspace
description: "Google Workspace integration via gws CLI. Create and manage Google Sheets and Drive files. Used for Layer 1 of the 3-layer data model (raw data, persistent, human-readable)."
user-invocable: false
scope: channel-leads
---

# Google Workspace Skill

Integration with Google Sheets and Drive via the `gws` CLI tool. Used for Layer 1 of the 3-layer data model: raw, persistent, human-readable storage.

> CLI Reference: https://github.com/googleworkspace/cli

## Prerequisites

1. **gws binary** must be installed and on PATH
2. **Authentication**: service account JSON or OAuth credentials
3. **Environment variables**:
   - `GOOGLE_APPLICATION_CREDENTIALS` — path to service account JSON
   - `GWS_ROOT_FOLDER_ID` — root Google Drive folder ID for all Xerus files

Verify setup:
```bash
gws version
gws auth status
```

## Sheets Operations

### Create a new spreadsheet
```bash
gws sheets create --title "Research: {topic} - $(date +%Y-%m-%d)"
```

Naming convention: `"Research: {topic} - {YYYY-MM-DD}"` or `"Metrics: {channel} - {YYYY-MM-DD}"`

### Append rows to a sheet
```bash
# Write data to temp file first
cat > /tmp/gws-rows.json << 'EOF'
{
  "values": [
    ["Column A", "Column B", "Column C"],
    ["data1", "data2", "data3"]
  ]
}
EOF

gws sheets append --spreadsheet-id "{SPREADSHEET_ID}" --range "Sheet1" --data @/tmp/gws-rows.json
```

### Read values from a sheet
```bash
gws sheets get --spreadsheet-id "{SPREADSHEET_ID}" --range "Sheet1!A1:Z100"
```

### Create sheet with headers and data
```bash
# Step 1: Create
SHEET_ID=$(gws sheets create --title "Research: {topic} - $(date +%Y-%m-%d)" --format json | jq -r '.spreadsheetId')

# Step 2: Write headers + data
cat > /tmp/gws-data.json << 'EOF'
{
  "values": [
    ["Source", "Title", "URL", "Engagement", "Key Finding", "Date"],
    ["Reddit", "Example post", "https://...", "150 upvotes", "Key insight here", "2026-03-10"]
  ]
}
EOF

gws sheets append --spreadsheet-id "$SHEET_ID" --range "Sheet1" --data @/tmp/gws-data.json
```

## Drive Operations

### Folder structure
```
Xerus/                          (GWS_ROOT_FOLDER_ID)
├── Research/                   Research outputs
├── Metrics/                    Channel metrics exports
├── Content/                    Content drafts and assets
└── Exports/                    Reports and deliverables
```

### Create a folder
```bash
gws drive mkdir --parent "$GWS_ROOT_FOLDER_ID" --name "Research"
```

### Upload a file
```bash
gws drive upload --parent "{FOLDER_ID}" --file "output/deliverables/report.md"
```

### List files in folder
```bash
gws drive list --parent "{FOLDER_ID}"
```

## Reference File Convention

After creating ANY Google file, create a local reference so other agents can find it:

### File location
```
data/drive/{descriptive-name}-{YYYY-MM-DD}.gsheet
```

### File format (JSON)
```json
{
  "url": "https://docs.google.com/spreadsheets/d/{id}",
  "spreadsheet_id": "{id}",
  "title": "Research: AI Agents - 2026-03-10",
  "created_by": "{your-slug}",
  "topic": "{topic}",
  "type": "research",
  "created_at": "2026-03-10T14:30:00Z"
}
```

### Register in DB
```sql
INSERT INTO google_files (url, file_id, title, type, folder, created_by, local_ref_path)
VALUES (
  'https://docs.google.com/spreadsheets/d/{id}',
  '{id}',
  '{title}',
  'sheet',
  'Research',
  '{your-slug}',
  'data/drive/{descriptive-name}-{YYYY-MM-DD}.gsheet'
);
```

## Common Patterns

### Pattern 1: Dump last30days research to Sheet
After running last30days research:
```bash
# Create sheet
SHEET_ID=$(gws sheets create --title "Research: $TOPIC - $(date +%Y-%m-%d)" --format json | jq -r '.spreadsheetId')

# Format findings as rows and append
# ... (construct JSON from research output)
gws sheets append --spreadsheet-id "$SHEET_ID" --range "Sheet1" --data @/tmp/gws-research.json

# Create local reference
cat > "data/drive/research-${TOPIC_SLUG}-$(date +%Y-%m-%d).gsheet" << EOF
{"url":"https://docs.google.com/spreadsheets/d/$SHEET_ID","spreadsheet_id":"$SHEET_ID","title":"Research: $TOPIC - $(date +%Y-%m-%d)","created_by":"$AGENT_SLUG","topic":"$TOPIC","type":"research","created_at":"$(date -u +%Y-%m-%dT%H:%M:%SZ)"}
EOF

# Register in DB
sqlite3 data/company.db "INSERT INTO google_files (url, file_id, title, type, folder, created_by, local_ref_path) VALUES ('https://docs.google.com/spreadsheets/d/$SHEET_ID', '$SHEET_ID', 'Research: $TOPIC - $(date +%Y-%m-%d)', 'sheet', 'Research', '$AGENT_SLUG', 'data/drive/research-${TOPIC_SLUG}-$(date +%Y-%m-%d).gsheet');"
```

### Pattern 2: Create metrics export Sheet
```bash
# Query metrics from DB
sqlite3 -json data/company.db "SELECT channel, metric_name, value, period FROM campaign_metrics WHERE period >= date('now', '-7 days') ORDER BY channel, period"

# Create sheet and append
SHEET_ID=$(gws sheets create --title "Metrics: Weekly - $(date +%Y-%m-%d)" --format json | jq -r '.spreadsheetId')
# ... format and append data
```

### Pattern 3: Upload deliverable to Drive
```bash
# Upload the file
FILE_ID=$(gws drive upload --parent "{CONTENT_FOLDER_ID}" --file "output/deliverables/{filename}" --format json | jq -r '.id')

# Create reference + register
```

## Browser-Native Workflows (Alternative to CLI)

When `gws` CLI is unavailable, or for interactive/visual work, use `agent-browser` to drive Google Workspace directly in the browser. See `.claude/skills/agent-browser/SKILL.md` for full reference.

### Create Sheet via Browser

```bash
agent-browser tab new "https://sheets.google.com/create"
agent-browser wait --load networkidle
agent-browser snapshot -i
# Use fill/click to add title, headers, data
```

### Create Doc via Browser

```bash
agent-browser tab new "https://docs.google.com/document/create"
agent-browser wait --load networkidle
agent-browser snapshot -i
# Use type/fill to write content
```

### Create Slides via Browser

```bash
agent-browser tab new "https://slides.google.com/create"
agent-browser wait --load networkidle
agent-browser snapshot -i
# Use click/type to build presentation
```

### When to Use CLI vs Browser

| Use Case | Approach |
|----------|----------|
| Batch append 100+ rows | `gws` CLI (faster, no UI overhead) |
| Create sheet with formatting | Browser (visual, interactive) |
| Read data programmatically | `gws` CLI (structured JSON output) |
| Create formatted doc/slides | Browser (Google Docs/Slides UI) |
| Quick file upload | `gws` CLI |
| Complex document editing | Browser |

## Fallback (No gws CLI AND No Browser)

If neither `gws` nor browser is available, skip Layer 1 operations and log to DB only. Add a note:
```sql
INSERT INTO research_reports (..., sheet_url) VALUES (..., 'SKIPPED: Google Workspace not available');
```

Do NOT block on missing Google Workspace access. Layers 2 and 3 are always available.
