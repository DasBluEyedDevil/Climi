# Claude Code Integration Guide

This guide explains how to integrate the Gemini CLI wrapper with Claude Code for efficient large-context code analysis.

## Overview

The Gemini agent wrapper (`gemini.agent.wrapper.sh`) enables Claude Code to leverage Gemini's 1M+ token context window for code analysis tasks while Claude handles implementation.

## Quick Start

```bash
# Make the wrapper executable
chmod +x skills/gemini.agent.wrapper.sh

# Basic usage
./skills/gemini.agent.wrapper.sh -d "@src/" "How is authentication implemented?"

# With a specialized role
./skills/gemini.agent.wrapper.sh -r security -d "@src/" "Security audit"

# Include git diff for verification
./skills/gemini.agent.wrapper.sh --diff -d "@src/" "Verify these changes"
```

## When to Use Gemini

### Use Gemini For:
- Reading files >100 lines
- Analyzing multiple files at once
- Understanding codebase architecture
- Tracing bugs across files
- Security or performance audits
- Pre-implementation exploration
- Post-change verification

### Handle Directly with Claude:
- Single-file edits
- Writing new code
- Running tests and builds
- Writing documentation

## Available Roles

| Role | Use Case |
|------|----------|
| `reviewer` | Code review and quality checks |
| `debugger` | Bug tracing and root cause analysis |
| `planner` | Architecture and implementation planning |
| `security` | Security vulnerability auditing |
| `auditor` | Codebase health assessment |
| `explainer` | Code explanation and documentation |
| `migrator` | Large-scale migration planning |
| `documenter` | Comprehensive documentation generation |
| `dependency-mapper` | Dependency graph analysis |
| `onboarder` | New developer onboarding guide |

Additional custom roles can be added in `.gemini/roles/`.

## Command Reference

```bash
./skills/gemini.agent.wrapper.sh [OPTIONS] "QUERY"

Options:
  -d, --dir DIRS        Directories to include (@src/ @lib/)
  -r, --role ROLE       Use specialized role
  -t, --template TMPL   Use query template
  --diff [TARGET]       Include git diff
  --verbose             Show status messages
  --dry-run             Preview without executing
```

## Response Format

Gemini responses follow a structured format:

```
## SUMMARY
[1-2 sentence overview]

## FILES
- path/to/file.ext:LINE - description

## ANALYSIS
[detailed findings]

## RECOMMENDATIONS
1. First action item
2. Second action item
```

---

## Real-World Workflow Examples

### Example 1: Understanding a Complex Codebase

**Scenario**: You've inherited an app and need to understand how authentication works.

```bash
./skills/gemini.agent.wrapper.sh -d "@app/src/main/java/com/app/auth/" "
How is authentication implemented? Show me:
1. Main classes and their responsibilities
2. Login state flow
3. How token refresh is handled
4. Key files with line numbers
"
```

### Example 2: Bug Tracing

**Scenario**: NullPointerException crash during logout.

```bash
./skills/gemini.agent.wrapper.sh -d "@app/src/main/java/" "
Bug: App crashes when logging out during active session
Error: NullPointerException in SessionManager.kt:245

Trace the complete call chain with file:line numbers.
"
```

### Example 3: Security Audit

```bash
./skills/gemini.agent.wrapper.sh -r security -d "@app/src/" "
Security audit for authentication system. Check for:
1. Password storage - hashed/salted?
2. JWT token handling - stored securely?
3. Hardcoded API keys?
4. SQL injection risks?
"
```

### Common Patterns

| Pattern | Flow |
|---------|------|
| Bug Investigation | Gemini traces -> Claude fixes -> Gemini verifies |
| New Feature | Gemini analyzes -> Claude implements -> Gemini checks |
| Security Review | Gemini audits -> Claude fixes -> Gemini re-audits |
| Refactoring | Gemini identifies -> Claude refactors -> Gemini verifies |

**Token Savings**: Using Gemini for analysis tasks typically reduces Claude's token usage by 95%+ compared to having Claude read the same files directly.
