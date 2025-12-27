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
./skills/gemini.agent.wrapper.sh -d "@app/src/" "How is [feature] implemented?"

# Trace a bug
./skills/gemini.agent.wrapper.sh -d "@app/src/" "Bug at [file:line]. Trace root cause."

# Find relevant files
./skills/gemini.agent.wrapper.sh -d "@app/src/" "Which files handle [functionality]?"

# Architecture overview
./skills/gemini.agent.wrapper.sh -d "@app/src/" "Explain [system] architecture with file organization."

# Review code quality
./skills/gemini.agent.wrapper.sh -d "@app/src/" "Review [files] for security and best practices."

# Verify changes
./skills/gemini.agent.wrapper.sh -d "@app/src/" "Changes: [summary]. Verify consistency."
```

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
✅ "How is BLE connection state managed? Show state flow with file paths and line numbers."

### Request Structured Output
❌ "Review this code"  
✅ "Review for: 1) Kotlin best practices, 2) coroutine safety, 3) memory leaks. Provide file:line references."

### Include Context
❌ "Find the bug"  
✅ "Bug: Crash at BleManager.kt:145 when disconnecting. Trace the disconnect flow through all files."

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
- Query patterns: [`skills/Gemini-Researcher.md`](skills/Gemini-Researcher.md)
- Integration guide: [`skills/Claude-Code-Integration.md`](skills/Claude-Code-Integration.md)
- Examples: [`EXAMPLES.md`](EXAMPLES.md)
