# Gemini Context Companion for Claude Code

Quick reference for using Gemini to provide large-context analysis to Claude Code.

## Core Concept

**Gemini = Research Assistant** with 1M+ token context window  
**Claude Code = Developer** who implements based on Gemini's analysis

## Workflow

```
1. Analyze (Gemini) → 2. Implement (Claude) → 3. Verify (Gemini)
```

### Step 1: Analyze with Gemini

Before reading any code, ask Gemini:

```bash
./skills/gemini.agent.wrapper.sh -d "@src/" "How is [feature] implemented? Provide file paths and line numbers."
```

### Step 2: Implement with Claude Code

Use Gemini's analysis to guide implementation in Claude Code. You now have:
- File paths to modify
- Line numbers for relevant code
- Architectural context
- Existing patterns to follow

### Step 3: Verify with Gemini

After implementation, verify consistency:

```bash
./skills/gemini.agent.wrapper.sh -d "@src/" "Changes made: [summary]. Verify architectural consistency and identify any issues."
```

## Quick Reference Commands

```bash
# Understand a feature
./skills/gemini.agent.wrapper.sh -d "@src/" "How is [feature] implemented?"

# Use specialized roles
./skills/gemini.agent.wrapper.sh -r security -d "@src/" "Security audit"
./skills/gemini.agent.wrapper.sh -r auditor -d "@src/" "Codebase health report"

# Trace a bug
./skills/gemini.agent.wrapper.sh -d "@src/" "Bug at [file:line]. Trace root cause."

# Include git diff for verification
./skills/gemini.agent.wrapper.sh --diff -d "@src/" "Verify these changes"

# Get structured JSON output
./skills/gemini.agent.wrapper.sh --schema issues -d "@src/" "Find problems"
```

## Output Format

Gemini responses are structured for easy parsing:

```
## SUMMARY
[1-2 sentence overview]

## FILES
- path/to/file.ext:LINE - brief description

## ANALYSIS
[detailed findings]

## RECOMMENDATIONS
1. First actionable item
2. Second actionable item
```

**Note**: Output is quiet by default (no decorative headers). Use `--verbose` for human debugging.

## When to Use Gemini

### ✅ Use Gemini For:
- Reading large files or entire directories
- Understanding codebase architecture
- Tracing bugs across multiple files
- Finding relevant code before modifying
- Reviewing implemented changes
- Security or performance audits
- Pattern searches across codebase

### ❌ Don't Use Gemini For:
- Simple single-file edits Claude can handle
- Implementing code (that's Claude's job)
- Writing tests or documentation (Claude does this)

## Best Practices

### Be Specific
❌ "How does this work?"  
✅ "How is user authentication managed? Show state flow with file paths and line numbers."

### Request Structured Output
❌ "Review this code"  
✅ "Review for: 1) Security issues, 2) error handling, 3) memory leaks. Provide file:line references."

### Include Context
❌ "Find the bug"  
✅ "Bug: Crash at AuthManager.kt:145 when logging out. Trace the logout flow through all files."

## Token Savings

Every time you're about to read a file in Claude Code, ask: **"Should Gemini read this instead?"**

The answer is almost always **YES** if:
- The file is >100 lines
- You need to read multiple files
- You're exploring unfamiliar code
- You're tracing logic across files

**Typical savings**: 95% reduction in Claude's token usage for analysis tasks.

## Platform Notes

The Gemini wrapper is a bash script:
- **Windows**: Requires WSL or Git Bash
- **macOS/Linux**: Native bash

## Installation

Gemini CLI: https://ai.google.dev/gemini-api/docs/cli

```bash
# Verify installation
gemini --version

# Make wrapper executable
chmod +x skills/gemini.agent.wrapper.sh
```

## More Information

- Full documentation: [`README.md`](README.md)
- Integration guide: [`skills/Claude-Code-Integration.md`](skills/Claude-Code-Integration.md)
- Examples: [`EXAMPLES.md`](EXAMPLES.md)
