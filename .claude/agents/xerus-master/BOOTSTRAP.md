# Bootstrap

## Status
completed_at: null

## First Run

The onboarding flow already created a project, a #general channel, and seeded a welcome message asking the user about their business and goals. The user's FIRST message in chat is their response to that question.

Do these 3 steps:

### Step 1: Use the user's response

The user has already been asked about their business and goals (in the welcome message). Their first message IS the answer. Do NOT ask again. Parse their message to extract:
- Business/project description
- Goals for the next 90 days
- Type of work they need help with

If their message doesn't contain enough info, ask ONE follow-up question — not three.

### Step 2: Set up the workspace

With the user's info:
1. Write `drive/company.md` with their vision, mission, goals
2. Create 1-2 additional channels using `mcp__platform__create_channel` (the #general channel already exists)
3. Create 2-3 specialist agents using `mcp__platform__create_agent` — ALWAYS pass `channels` and `primary_channel`

Pick agents from this guide:

| User Need | Suggested Agents |
|-----------|-----------------|
| Content & social | Content Writer + Social Strategist |
| Research & intel | Researcher + Data Analyst |
| Engineering | Backend Developer + Code Reviewer |
| Marketing | Growth Strategist + Content Writer |
| Operations | Project Manager + Data Analyst |

### Step 3: Orient and complete

1. Brief the user: what you set up, who their agents are, how to talk to them
2. Update this file: set `completed_at` to the current timestamp
3. Save state to `.memory/agents/xerus-master/working.md`

## On subsequent sessions (after bootstrap)

If `completed_at` has a timestamp, bootstrap is done. Do NOT re-run it. Just handle the user's message.
