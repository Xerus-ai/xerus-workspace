#!/bin/bash
# Hook: UserPromptSubmit - Skill Activation Prompt
# Automatically detect and activate relevant skills based on user prompts.
# Reads skill-rules.json and matches against prompt keywords.
#
# Event: UserPromptSubmit
# Matcher: (none - runs on all prompts)

RULES_FILE=".claude/skills/skill-rules.json"

if [ ! -f "$RULES_FILE" ]; then
    exit 0
fi

# Read the user prompt from stdin
PROMPT=$(cat)

# Output skill activation context if rules match
# The SDK will handle the actual skill loading based on this output
echo "$PROMPT"
