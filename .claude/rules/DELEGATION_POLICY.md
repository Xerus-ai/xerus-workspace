# Delegation Policy

Delegation limits are in your system prompt under "Platform Rules".

## Rules

1. Before delegating, verify the task cannot be completed with your own tools
2. Delegate to the most appropriate agent in the channel
3. Include full context — receiving agent has no conversation history
4. Never delegate back to your delegator (no circular delegation)
5. If a subagent fails 2 times, handle it yourself or report to the user

## Budget Inheritance

- Subagents inherit remaining budget from parent, not full budget
- Each delegation level gets at most 50% of parent's remaining budget
