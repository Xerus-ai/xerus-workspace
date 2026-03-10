# Bootstrap

## Status
completed_at: null

## First Run Checklist

- [ ] Read workspace CLAUDE.md and understand workspace structure and goal hierarchy
- [ ] Read SOUL.md and calibrate personality
- [ ] Read shared/knowledge/company.md — this is your north star, currently a template
- [ ] Discover user's business and priorities (2-3 questions):
  - What is your business/project?
  - What are your top 3 goals for the next 90 days?
  - What kind of work do you need help with? (marketing, dev, research, ops, etc.)
- [ ] Populate shared/knowledge/company.md with user's answers:
  - Vision, Mission, Values, North Star Metric
  - Current Stage, Who We Serve, What We Build
  - Current Goals (company-wide, derived from their 90-day priorities)
- [ ] Determine workspace setup path:
  - Path A: "Start fresh" -- create projects and channels from scratch
  - Path B: "Bring my company" -- import existing structure
- [ ] Build the office: create first project + 2-3 channels
  - Use templates from shared/office/templates/ for project and channel CLAUDE.md files
  - Set channel missions and metrics targets that trace back to company goals
- [ ] Initialize data ecosystem:
  - Verify company.db initialized (sqlite3 data/company.db ".tables")
  - Load domain extensions if needed (data/extensions/*.sql)
  - Confirm .memory/entities/ directories exist
- [ ] Suggest 2-3 starter agents based on user needs
- [ ] Set up one quick win deliverable for 24h delivery
- [ ] Orient user: show workspace, explain channels, introduce agents, explain goal hierarchy
- [ ] Run workspace-sync to ensure all agent files are current
- [ ] Update STATUS.md with initial state
- [ ] Update USER.md with first impressions of communication style
- [ ] Mark bootstrap complete (set completed_at to current timestamp)

## Suggestion Guide

| User Need | Suggested Agents | Why |
|-----------|-----------------|-----|
| Content & social | Content Writer + Social Strategist | Writing + distribution |
| Research & intel | Researcher + Data Analyst | Discovery + analysis |
| Engineering | Backend Developer + Code Reviewer | Build + quality |
| Marketing | Growth Strategist + Content Writer | Reach + content |
| Operations | Project Manager + Data Analyst | Coordination + insights |
| Unsure | Researcher + Content Writer | Research + writing covers most needs |

## Guardrails

- User overwhelmed? Slow down, offer basics only
- User wants to skip? Respect it, minimal setup
- User asks about cost? Explain credits transparently
- More than 10 exchanges? Wrap up and let them explore
