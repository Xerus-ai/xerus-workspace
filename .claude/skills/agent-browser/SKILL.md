---
name: agent-browser
description: "Browser automation via agent-browser CLI. Navigate, interact, screenshot, and manage browser sessions. Used for web automation, Google Workspace interaction, previewing deliverables, and any task requiring a real browser."
user-invocable: false
scope: all-agents
allowed-tools: Bash(agent-browser:*)
---

# Browser Automation with agent-browser

CLI-based browser automation for navigating websites, filling forms, extracting data, and interacting with web applications. All agents share a single Chromium instance visible via the workspace browser pane.

> CLI Reference: https://github.com/vercel-labs/agent-browser

## Connection

In the Xerus sandbox, Chromium runs on the desktop display. Connect via CDP:

```bash
# All commands automatically connect to the shared Chromium instance
# The AGENT_BROWSER_CDP_PORT env var is pre-configured
agent-browser open <url>
```

## Core Workflow

1. Navigate: `agent-browser open <url>`
2. Snapshot: `agent-browser snapshot -i` (returns interactive elements with refs like `@e1`, `@e2`)
3. Interact using refs from the snapshot
4. Re-snapshot after navigation or significant DOM changes

## Commands

### Navigation

```bash
agent-browser open <url>        # Navigate to URL
agent-browser back              # Go back
agent-browser forward           # Go forward
agent-browser reload            # Reload page
agent-browser close             # Close browser
```

### Snapshot (page analysis)

```bash
agent-browser snapshot            # Full accessibility tree
agent-browser snapshot -i         # Interactive elements only (recommended)
agent-browser snapshot -c         # Compact output
agent-browser snapshot -s "#main" # Scope to CSS selector
```

### Interactions (use @refs from snapshot)

```bash
agent-browser click @e1           # Click
agent-browser fill @e2 "text"     # Clear and type
agent-browser type @e2 "text"     # Type without clearing
agent-browser press Enter         # Press key
agent-browser hover @e1           # Hover
agent-browser check @e1           # Check checkbox
agent-browser select @e1 "value"  # Select dropdown
agent-browser scroll down 500     # Scroll page
agent-browser upload @e1 file.pdf # Upload files
```

### Get information

```bash
agent-browser get text @e1        # Get element text
agent-browser get html @e1        # Get innerHTML
agent-browser get value @e1       # Get input value
agent-browser get attr @e1 href   # Get attribute
agent-browser get title           # Get page title
agent-browser get url             # Get current URL
```

### Screenshots

```bash
agent-browser screenshot          # Screenshot to stdout
agent-browser screenshot path.png # Save to file
agent-browser screenshot --full   # Full page
agent-browser pdf output.pdf      # Save as PDF
```

### Tabs (multi-agent tab isolation)

```bash
agent-browser tab                 # List tabs
agent-browser tab new [url]       # New tab (each agent opens its own)
agent-browser tab 2               # Switch to tab
agent-browser tab close           # Close tab
```

### Session State (persist logins)

```bash
agent-browser state save /home/daytona/.browser/state/{service}.json
agent-browser state load /home/daytona/.browser/state/{service}.json
```

### Cookies & Storage

```bash
agent-browser cookies                     # Get all cookies
agent-browser cookies set name value      # Set cookie
agent-browser storage local               # Get all localStorage
agent-browser storage local set k v       # Set value
```

### Wait

```bash
agent-browser wait @e1                     # Wait for element
agent-browser wait 2000                    # Wait milliseconds
agent-browser wait --text "Success"        # Wait for text
agent-browser wait --load networkidle      # Wait for network idle
```

### Semantic Locators (alternative to refs)

```bash
agent-browser find role button click --name "Submit"
agent-browser find text "Sign In" click
agent-browser find label "Email" fill "user@test.com"
```

## Tab Isolation Rule

Each agent MUST open its own tab. Never reuse or navigate a tab another agent is using.

```bash
# Correct: open your own tab
agent-browser tab new "https://sheets.google.com"

# Wrong: navigating in an existing tab that may belong to another agent
agent-browser open "https://sheets.google.com"  # Only if you know no one else is using it
```

## Google Workspace via Browser

When the `gws` CLI is unavailable or for interactive work, use the browser directly:

### Create a Google Sheet

```bash
agent-browser tab new "https://sheets.google.com/create"
agent-browser wait --load networkidle
agent-browser snapshot -i
# Fill title, add headers, enter data using fill/click
```

### Create a Google Doc

```bash
agent-browser tab new "https://docs.google.com/document/create"
agent-browser wait --load networkidle
agent-browser snapshot -i
# Write content using type/fill
```

### Create a Google Slides Presentation

```bash
agent-browser tab new "https://slides.google.com/create"
agent-browser wait --load networkidle
agent-browser snapshot -i
# Build slides using click/type
```

### Open Existing Google File

```bash
# Read the local reference to get the URL
# cat data/drive/{name}.gsheet | jq -r '.url'
agent-browser tab new "https://docs.google.com/spreadsheets/d/{SPREADSHEET_ID}"
```

## Preview Deliverables

Show completed work to the user via the browser pane:

```bash
# HTML dashboard
agent-browser open "file:///home/daytona/shared/dashboard/channel.html"

# Local web app (if agent built one on a preview port)
agent-browser open "http://localhost:3000"

# Any deliverable rendered as HTML
agent-browser open "file:///home/daytona/projects/{project}/channels/{channel}/output/deliverables/{file}.html"
```

The user sees this live in the browser pane on the frontend.

## Requesting Human Help

When you encounter something you cannot handle (CAPTCHA, payment, 2FA, login), use the platform intervention tool:

```
platform.pause_execution({
  reason: "manual",
  checkpoint: {
    scenario: "browser_auth",
    message: "Please log into Google in the browser window",
    url: "https://accounts.google.com",
    ui_hint: "browser"
  }
})
```

The user sees the browser pane auto-expand, solves the problem, and clicks Resume. Your session resumes from the checkpoint.

## Notes

- Refs are stable per page load but change on navigation
- Always snapshot after navigation to get new refs
- Use `fill` instead of `type` for input fields to clear existing text
- Use `--json` flag for machine-readable output
- Browser state (cookies, localStorage) persists at `/home/daytona/.browser/chromium-data/`
