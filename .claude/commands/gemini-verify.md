# Gemini Verify

Verify implementation changes for consistency and regressions.

## Usage

```
/gemini-verify [description of changes]
```

## What This Does

1. Invokes Gemini CLI with the verification template
2. Includes git diff of recent changes
3. Checks for architectural consistency
4. Identifies potential regressions or issues

## Example Invocations

```bash
# Verify recent changes
pwsh -Command "& ~/.claude/skills/gemini.ps1 -t verify --diff 'Added password reset functionality'"

# Verify against specific commit
pwsh -Command "& ~/.claude/skills/gemini.ps1 -t verify --diff 'HEAD~3' 'Refactored authentication module'"

# Security verification
pwsh -Command "& ~/.claude/skills/gemini.ps1 -r security --diff 'Added new user input handling'"
```

## When to Use

- After implementing a feature
- Before committing changes
- After refactoring
- When changes touch multiple files

## Response Format

Gemini returns:
- SUMMARY: Overall assessment
- FILES: Files checked with any issues found
- ANALYSIS: Detailed consistency check
- RECOMMENDATIONS: Issues to fix before committing

## Instructions for Claude

When invoked, run gemini.ps1 via PowerShell (pwsh) with the verify template and
--diff flag. Always include the user's change description as the final, quoted
argument or the wrapper will exit with "Prompt is required". Address any issues
identified before considering the implementation complete.
