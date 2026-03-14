#!/bin/bash
# Hook: UserPromptSubmit - Skill Activation Prompt
# Automatically detect and activate relevant skills based on user prompts.
# Reads skill-rules.json and matches against prompt keywords.
#
# Event: UserPromptSubmit
# Matcher: (none - runs on all prompts)

AGENT_SLUG="${XERUS_AGENT_SLUG:-unknown}"
XERUS_WORKSPACE_ROOT="${XERUS_WORKSPACE_ROOT:?XERUS_WORKSPACE_ROOT must be set}"

source "$(dirname "$0")/_lib.sh"
audit "SkillActivationPrompt"

RULES_FILE="$XERUS_WORKSPACE_ROOT/.claude/skills/skill-rules.json"

if [ ! -f "$RULES_FILE" ]; then
    exit 0
fi

# Read the user prompt from stdin
PROMPT=$(cat)

# Output skill activation context if rules match
# The SDK will handle the actual skill loading based on this output
echo "$PROMPT"
