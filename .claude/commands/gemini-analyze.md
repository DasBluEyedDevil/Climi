# Gemini Analyze

Delegate codebase analysis to Gemini's large context window.

## Usage

```
/gemini-analyze [directory] [question]
```

## What This Does

1. Invokes Gemini CLI with the specified directory
2. Returns structured analysis with file:line references
3. Claude then uses this to implement changes efficiently

## Example Invocations

```bash
# Understand a feature (run gemini.ps1 via PowerShell)
pwsh -Command "& ~/.claude/skills/gemini.ps1 -d '@src/' 'How is authentication implemented?'"

# Find where to add code
pwsh -Command "& ~/.claude/skills/gemini.ps1 -r planner -d '@src/' 'Where should I add a new API endpoint for user profiles?'"

# Analyze architecture
pwsh -Command "& ~/.claude/skills/gemini.ps1 -t architecture -d '@.' 'Overview of the project structure'"
```

## When to Use

- Before reading unfamiliar code
- When you need to understand architecture
- When searching for patterns across files
- Before implementing a feature

## Response Format

Gemini returns:
- SUMMARY: 1-2 sentence overview
- FILES: List of path:line references
- ANALYSIS: Detailed findings
- RECOMMENDATIONS: Actionable next steps

## Instructions for Claude

When invoked, run gemini.ps1 via PowerShell (pwsh); do not call it directly from bash.
Always include the user's question as the final, quoted argument or the wrapper will
exit with "Prompt is required". Parse the response and use the file:line references
to guide implementation.
