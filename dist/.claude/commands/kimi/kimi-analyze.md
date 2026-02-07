---
description: Deep codebase analysis using Kimi K2.5's large context window
---

# Kimi Analyze

Delegate codebase analysis to Kimi K2.5's large context window.

## Usage

```
/kimi-analyze [directory] [question]
```

## What This Does

1. Invokes Kimi CLI via the wrapper with the reviewer role
2. Kimi analyzes the codebase with its massive context window
3. Returns structured analysis with file:line references
4. Claude uses the findings to guide implementation

## Example Invocations

```bash
# Analyze authentication flow
bash skills/kimi.agent.wrapper.sh -r reviewer -w src/ "How is authentication implemented?"

# Find where to add new functionality
bash skills/kimi.agent.wrapper.sh -r reviewer -w src/api/ "Where should I add a new endpoint for user profiles?"

# Understand architecture patterns
bash skills/kimi.agent.wrapper.sh -r reviewer -w . "What design patterns are used in this codebase?"

# Deep analysis with thinking mode
bash skills/kimi.agent.wrapper.sh -r reviewer --thinking -w src/ "Explain the data flow from API to database"
```

## When to Use

- **Understanding architecture:** Before modifying unfamiliar code
- **Finding patterns:** When searching for conventions across files
- **Pre-implementation research:** Before implementing a feature
- **Code review preparation:** Understanding how components interact
- **Onboarding:** Getting up to speed on a new codebase

## Response Format

Kimi returns structured output with these sections:

- **SUMMARY:** 1-2 sentence overview of findings
- **FILES:** List of path:line references to relevant code
- **ANALYSIS:** Detailed findings and explanations
- **RECOMMENDATIONS:** Actionable next steps for implementation

## Instructions for Claude

When this command is invoked, execute the kimi wrapper via bash (NOT PowerShell):

```bash
bash ~/.claude/skills/kimi.agent.wrapper.sh -r reviewer -w [directory] "[question]"
```

**Required parameters:**
- `-r reviewer` - Uses the reviewer agent role (analysis-focused, read-only)
- Final quoted argument - The user's question or analysis request

**Optional parameters:**
- `-w [path]` - Set working directory for analysis scope
- `--thinking` - Enable deeper reasoning for complex analysis
- `--verbose` - Show wrapper debug output

**Important:**
- Always include the user's question as the final quoted argument
- The reviewer role is read-only (no file modifications)
- Parse the SUMMARY and FILES sections to guide your implementation
- Use file:line references to read specific code sections
