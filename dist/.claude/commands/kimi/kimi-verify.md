---
description: Verify implementation changes for consistency and regressions
---

# Kimi Verify

Verify implementation changes for consistency and regressions using Kimi K2.5.

## Usage

```
/kimi-verify [description of changes]
```

## What This Does

1. Invokes Kimi CLI with the verify template AND --diff flag
2. Captures git diff of recent changes automatically
3. Kimi analyzes changes for consistency, regressions, and issues
4. Returns verification report with any problems to address

## Example Invocations

```bash
# Verify recent changes before committing
bash skills/kimi.agent.wrapper.sh -t verify --diff "Added password reset functionality"

# Verify refactoring didn't break anything
bash skills/kimi.agent.wrapper.sh -t verify --diff "Refactored authentication module to use JWT"

# Verify with deep analysis
bash skills/kimi.agent.wrapper.sh -t verify --diff --thinking "Migrated database queries to new ORM"

# Security-focused verification
bash skills/kimi.agent.wrapper.sh -r security --diff "Added new user input handling"

# Verify API changes
bash skills/kimi.agent.wrapper.sh -t verify --diff "Updated API response format for user endpoints"
```

## When to Use

- **After implementing:** Verify feature implementation is complete and correct
- **Before committing:** Final check before creating a commit
- **After refactoring:** Ensure behavior wasn't changed unintentionally
- **Multi-file changes:** When changes span multiple files
- **Security-sensitive changes:** When touching auth, input handling, etc.

## Response Format

Kimi returns structured output with these sections:

- **SUMMARY:** Overall verification assessment (PASS/WARN/FAIL)
- **FILES:** Files changed with any issues found per file
- **ANALYSIS:** Detailed consistency check including:
  - Changes reviewed
  - Potential regressions identified
  - Missing test coverage
  - Inconsistencies with existing code
- **RECOMMENDATIONS:** Issues to fix before committing

## Key Flags

The verify command uses two key components:

1. **`-t verify`** - Uses the verify template which prepends verification instructions
2. **`--diff`** - Captures git diff (staged + unstaged vs HEAD) and includes in context

Together, these ensure Kimi has both the verification mindset and the actual changes to analyze.

## Advanced Usage

```bash
# Combine with security role for security-focused verification
bash skills/kimi.agent.wrapper.sh -r security -t verify --diff "Added API key validation"

# Add thinking for complex verification
bash skills/kimi.agent.wrapper.sh -t verify --diff --thinking "Restructured error handling across all services"
```

## Instructions for Claude

When this command is invoked, execute the kimi wrapper via bash (NOT PowerShell):

```bash
bash ~/.claude/skills/kimi.agent.wrapper.sh -t verify --diff "[change description]"
```

**Required parameters:**
- `-t verify` - Uses the verification template
- `--diff` - ALWAYS include this flag to capture git changes
- Final quoted argument - Description of changes made

**Optional parameters:**
- `-r security` - Add security role for security-focused verification
- `--thinking` - Enable deeper reasoning for complex changes
- `-w [path]` - Focus verification on specific directory
- `--verbose` - Show wrapper debug output

**Important:**
- ALWAYS include both `-t verify` AND `--diff` flags
- The --diff flag captures all staged and unstaged changes vs HEAD
- Address any RECOMMENDATIONS before considering implementation complete
- For security-sensitive changes, add `-r security` for deeper security analysis
