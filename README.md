# Gemini Context Companion for Claude Code

A token-efficient workflow that leverages Gemini's 1M+ token context window to provide comprehensive code analysis to Claude Code, reducing Claude's token consumption by up to 95%.

## Overview

Instead of Claude Code reading large files and entire codebases directly (expensive), this workflow delegates code analysis and research to **Gemini**, which has a massive 1M+ token context window. Gemini reads entire codebases, provides architectural insights, traces bugs across multiple files, and delivers concise summaries back to Claude for implementation.

**Result**: Claude uses ~300 tokens for analysis instead of ~6,500+ tokens (95% savings).

## Why Gemini as a Companion?

| Challenge | Solution |
|-----------|----------|
| **Large codebases** | Gemini reads entire directories with 1M+ context window |
| **Token limits** | Claude delegates reading to Gemini, conserves its tokens |
| **Complex analysis** | Gemini traces patterns across hundreds of files |
| **Architectural understanding** | Gemini provides high-level overviews before implementation |
| **Bug tracing** | Gemini follows call stacks through multiple files |

## Prerequisites

### Platform
- **Windows**: WSL or Git Bash required (wrapper is a bash script)
- **macOS/Linux**: Native bash

### Gemini CLI

Install the Gemini CLI following the [official documentation](https://ai.google.dev/gemini-api/docs/cli).

Verify installation:
```bash
gemini --version
```

## Quick Start

### 1. Clone and Setup
```bash
git clone <repo-url>
cd Multi-Agent-Workflow
chmod +x skills/gemini.agent.wrapper.sh
```

### 2. Basic Usage

**Analyze code architecture**:
```bash
./skills/gemini.agent.wrapper.sh -d "@src/" "How is authentication implemented? Provide file paths with line numbers."
```

**Trace a bug**:
```bash
./skills/gemini.agent.wrapper.sh -d "@app/src/" "Bug: Connection drops after 30 seconds. Trace the timeout handling logic through all files."
```

**Understand a feature**:
```bash
./skills/gemini.agent.wrapper.sh -d "@app/" "Explain how user authentication flows from login UI to API. Show the complete data pipeline."
```

## Workflow: Claude Code + Gemini

```
┌─────────────┐          ┌─────────────┐
│    Claude   │◄────────▶│   Gemini    │
│    Code     │          │  Analyzer   │
│ (Developer) │          │  (Research) │
└─────────────┘          └─────────────┘
      │                        │
      │ 1. Query Analysis      │
      │ (~300 tokens)          │
      ├───────────────────────▶│
      │                        │ Reads entire
      │                        │ codebase
      │                        │ (0 Claude tokens)
      │                        │
      │ 2. Analysis Results    │
      │ (concise summary)      │
      │◄───────────────────────┤
      │                        │
      ▼                        │
 3. Implement                  │
 (Claude Code)                 │
      │                        │
      │ 4. Verify Changes      │
      ├───────────────────────▶│
      │                        │
      │ 5. Verification Report │
      │◄───────────────────────┤
      ▼
   Complete
```

## File Structure

```
./
├── .gemini/                       # Custom roles and templates
│   ├── roles/                     # Custom role definitions
│   └── templates/                 # Custom query templates
├── README.md                      # This file
├── CLAUDE.md                      # Quick reference for Claude Code
├── EXAMPLES.md                    # Real-world workflow examples
├── GEMINI.md                      # Gemini context file
└── skills/
    ├── gemini.agent.wrapper.sh    # Gemini CLI wrapper (main tool)
    ├── Claude-Code-Integration.md # Integration guide
    └── pre-commit.hook            # Git pre-commit verification
```

## Gemini Wrapper Reference

```bash
./skills/gemini.agent.wrapper.sh [OPTIONS] "<prompt>"

Options:
  -d, --dir DIRS        Directories to include (e.g., "@src/ @lib/")
  -a, --all-files       Include all files
  -r, --role ROLE       Use predefined role (reviewer, planner, security, etc.)
  -t, --template TMPL   Use query template (feature, bug, verify, architecture)
  -m, --model MODEL     Specify model (default: gemini-3-pro-preview)
  --diff [TARGET]       Include git diff in prompt
  --cache               Cache response for repeated queries
  --schema SCHEMA       Structured output (files, issues, plan, json)
  --batch FILE          Process multiple queries from file
  --verbose             Show status messages (quiet by default for AI consumption)
  --dry-run             Show prompt without executing
```

**Note**: Output is quiet by default (only Gemini's response), optimized for Claude Code consumption. Use `--verbose` for human debugging.

### Important: Handling Large Codebases

When analyzing very large directories (1000s of files), use targeted subdirectories to avoid file handle overflow:

❌ **Don't**: Analyze entire large directory
```bash
./skills/gemini.agent.wrapper.sh -d "@large-project/" "analyze code"
```

✅ **Do**: Use targeted subdirectories or search first
```bash
# Analyze specific subdirectories
./skills/gemini.agent.wrapper.sh -d "@large-project/src/auth/" "analyze authentication"

# Or use grep first to find relevant files
grep -r "authentication" src/ -l | head -20
./skills/gemini.agent.wrapper.sh -d "@src/auth/" "analyze authentication"
```

## Common Query Patterns

### Architecture Analysis
```bash
./skills/gemini.agent.wrapper.sh -d "@app/src/" "
Analyze architecture for implementing [feature].

Provide:
1. Current patterns and file organization
2. Files that will be affected
3. Dependencies and risks
4. Recommended approach with examples from existing code
"
```

### Bug Tracing
```bash
./skills/gemini.agent.wrapper.sh -d "@app/src/" "
Bug: [description]
Location: [file:line]

Trace:
1. Root cause through call stack
2. All affected files with line numbers
3. Similar patterns with same issue
4. Recommended fix
"
```

### Implementation Verification
```bash
./skills/gemini.agent.wrapper.sh -d "@app/src/" "
Changes implemented:
- [file1]: [changes]
- [file2]: [changes]

Verify:
1. Architectural consistency
2. No regressions
3. Best practices followed
4. Security implications
5. Edge cases handled
"
```

## Token Savings Examples

### Example 1: Understanding API Layer

**❌ Old Way (Claude reads directly)**:
- Claude reads ApiClient.kt (2k tokens)
- Claude reads AuthService.kt (3k tokens)
- Claude reads UserRepository.kt (1.5k tokens)
- **Total: 6.5k tokens**

**✅ New Way (Gemini analyzes)**:
- Claude queries Gemini (300 tokens)
- Gemini reads all files (0 Claude tokens)
- Gemini responds with summary (0 Claude tokens)
- **Total: 300 tokens (95% savings!)**

### Example 2: Full Codebase Audit

**❌ Old Way**:
- Claude would need to read chunks of the codebase
- Multiple context windows required
- Estimated: 50k+ tokens

**✅ New Way**:
- Single Gemini query with `--all-files`
- Comprehensive audit with 0 Claude read tokens
- Claude only pays for the query and result
- **Total: ~500 tokens (99% savings!)**

## Best Practices

### ✅ Do
- **Always query Gemini before implementing** - Let Gemini read the codebase first
- **Be specific** - Request file paths, line numbers, and code excerpts
- **Use structured prompts** - Ask for numbered lists and clear sections
- **Include context** - Mention error messages, file locations, or symptoms
- **Verify changes** - Ask Gemini to review your implementation for consistency

### ❌ Don't
- **Skip analysis** - Don't have Claude read large files directly
- **Use vague prompts** - Avoid "how does this work?" without specifics
- **Forget follow-up** - Always verify changes with Gemini after implementation
- **Overload queries** - Break complex questions into focused queries

## Integration with Claude Code

See [`skills/Claude-Code-Integration.md`](skills/Claude-Code-Integration.md) for detailed integration patterns and workflows.

See [`EXAMPLES.md`](EXAMPLES.md) for real-world examples of Gemini-Claude Code workflows.

## Troubleshooting

### "command not found: gemini"
Ensure Gemini CLI is installed and in PATH. On Windows, run from WSL or Git Bash.

### EMFILE: too many open files
Use targeted subdirectories instead of entire large projects:
```bash
# Instead of analyzing entire project
./skills/gemini.agent.wrapper.sh -d "@large-project/" "..."

# Analyze specific subdirectories
./skills/gemini.agent.wrapper.sh -d "@large-project/src/specific/" "..."
```

### Wrapper permission denied
```bash
chmod +x skills/gemini.agent.wrapper.sh
```

## What Happened to Codex and Copilot?

This repository previously included Codex and Copilot as "engineering subagents" for implementation work. The repository has been refocused on Gemini's unique strength: its massive context window for research and analysis as a companion to Claude Code.

If you need the multi-agent version, see the [`.archive/`](.archive/) directory and git history.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Update Gemini-related documentation
4. Test wrapper script
5. Submit PR

## License

MIT
