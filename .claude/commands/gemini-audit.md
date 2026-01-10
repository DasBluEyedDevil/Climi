# Gemini Audit

Perform comprehensive codebase audits using Gemini's full context.

## Usage

```
/gemini-audit [type] [directory]
```

## Audit Types

- `security` - Security vulnerability scan
- `health` - Overall codebase health report
- `deps` - Dependency analysis
- `performance` - Performance issue identification

## Example Invocations

```bash
# Security audit
pwsh -Command "& ~/.claude/skills/gemini.ps1 -r security -d '@src/' 'Full security audit'"

# Codebase health
pwsh -Command "& ~/.claude/skills/gemini.ps1 -r auditor -d '@.' 'Codebase health report'"

# Performance audit
pwsh -Command "& ~/.claude/skills/gemini.ps1 -t performance -d '@src/' 'Find performance issues'"

# Dependency mapping
pwsh -Command "& ~/.claude/skills/gemini.ps1 -r dependency-mapper -d '@.' 'Map all dependencies'"
```

## When to Use

- Before major releases
- During security reviews
- When assessing tech debt
- When onboarding to a new codebase

## Response Format

Gemini returns severity-rated findings:
- CRITICAL: Immediate attention required
- HIGH: Should fix soon
- MEDIUM: Address when possible
- LOW: Nice to fix

## Instructions for Claude

When invoked, run gemini.ps1 via PowerShell (pwsh) and select the appropriate
role based on audit type. Always include the user's audit prompt as the final,
quoted argument or the wrapper will exit with "Prompt is required". Present
findings to the user and offer to address high-priority issues.
