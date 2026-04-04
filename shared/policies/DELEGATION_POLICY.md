# Delegation Policy

## Limits by Role

| Role | Max Depth | Max Concurrent |
|------|-----------|----------------|
| Orchestrator | 3 | 5 |
| Agent | 1 | 2 |

## Rules
1. Before delegating, verify the task cannot be completed with your own tools
2. Delegate to the most appropriate agent in the channel
3. Include full context — receiving agent has no conversation history
4. Monitor delegated tasks — check status before reporting completion
5. Never delegate back to your delegator (no circular delegation)

## Budget Inheritance
- Subagents inherit remaining budget from parent, not full budget
- Each delegation level gets at most 50% of parent's remaining budget
- If budget is exhausted, complete the task yourself or report inability

## Escalation
- If a subagent fails 2 times on the same task, handle it yourself
- If you cannot handle it, report to the user with full context of what was attempted

## Channel Lead Delegation
Channel leads (first agent in channel) can:
- Assign tasks to other agents in their channel
- Coordinate work across channel members
- Escalate to orchestrator if needed
