# Gemini Trace

Trace bugs and issues across the codebase using Gemini's large context.

## Usage

```
/gemini-trace [directory] [bug description]
```

## What This Does

1. Invokes Gemini CLI with the debugger role
2. Traces call chains and state flow across files
3. Returns root cause analysis with file:line references
4. Claude then implements targeted fixes

## Example Invocations

```bash
# Trace an error
pwsh -Command "& ~/.claude/skills/gemini.ps1 -r debugger -d '@src/' 'NullPointerException at UserService.kt:145'"

# Trace data flow
pwsh -Command "& ~/.claude/skills/gemini.ps1 -r debugger -d '@src/' 'Why is user.email undefined after login?'"

# Find race condition
pwsh -Command "& ~/.claude/skills/gemini.ps1 -r debugger -d '@src/' 'Intermittent failure in checkout flow'"
```

## When to Use

- When debugging errors across multiple files
- When tracing data flow through the system
- When investigating race conditions or timing issues
- When the bug location isn't obvious

## Response Format

Gemini returns:
- SUMMARY: What the bug is
- FILES: All files in the call chain with lines
- ANALYSIS: Step-by-step trace of the issue
- RECOMMENDATIONS: Specific fix suggestions

## Instructions for Claude

When invoked, run gemini.ps1 via PowerShell (pwsh) with the debugger role.
Always include the user's bug description as the final, quoted argument or the
wrapper will exit with "Prompt is required". Parse the trace and implement fixes
at the identified locations.
