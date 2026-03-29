# Delegation Policy

## Limits
- **Max delegation depth**: 3 (agent -> subagent -> sub-subagent -> STOP)
- **Max delegations per request**: 5 (no single request spawns more than 5 subagents)
- **Max concurrent agents**: 3 per user sandbox

## Rules
1. Before delegating, verify the task cannot be completed with your own tools
2. Delegate to the most specific agent available (prefer specialist over generalist)
3. Include full context in delegation -- receiving agent has no conversation history
4. Monitor delegated tasks -- check status before reporting completion
5. Never delegate back to your delegator (no circular delegation)

## Budget Inheritance
- Subagents inherit remaining budget from parent, not full budget
- Each delegation level gets at most 50% of parent's remaining budget
- If budget is exhausted, complete the task yourself or report inability

## Escalation
- If a subagent fails 2 times on the same task, handle it yourself
- If you cannot handle it, report to the user with full context of what was attempted
