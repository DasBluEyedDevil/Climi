# Gemini CLI: Research Subagent for Claude Code

A Claude Skill that makes Gemini CLI a seamless research subagent. Gemini's 1M+ token context window handles large-scale code analysis, while Claude handles implementation.

## Installation

### Option 1: Copy Skill to Global Directory (Recommended)
```bash
# Copy the skill to Claude's global skills directory
cp -r .claude/skills/gemini-research ~/.claude/skills/
```

### Option 2: Use Project-Level Skill
The skill is already in `.claude/skills/gemini-research/` - Claude will auto-discover it when working in this project.

### Prerequisites
1. **Gemini CLI**: Install from [official docs](https://ai.google.dev/gemini-api/docs/cli)
2. **Platform**: WSL or Git Bash on Windows, native bash on macOS/Linux

```bash
gemini --version  # Verify installation
chmod +x skills/gemini.agent.wrapper.sh
```

## How It Works

```
Claude Code (Engineer)          Gemini CLI (Research)
        │                              │
        │ 1. Invoke wrapper            │
        ├─────────────────────────────▶│
        │                              │ Reads entire
        │                              │ codebase (1M+ tokens)
        │                              │
        │ 2. Structured response       │
        │◀─────────────────────────────┤
        │                              │
        ▼                              
 3. Implement based on analysis        
```

Claude automatically invokes the skill when it needs large-context analysis. The skill instructs Claude on when and how to use Gemini.

## File Structure

```
./
├── .claude/
│   ├── settings.json          # Hooks to remind Claude to use Gemini
│   └── skills/gemini-research/
│       └── SKILL.md           # Claude Skill definition
├── .gemini/
│   ├── roles/                 # Custom expert roles
│   └── templates/             # Query templates
├── GeminiContext.md           # Context injected into every Gemini query
├── skills/Claude-Code-Integration.md  # Integration guide with examples
├── README.md                  # This file
└── skills/
    ├── gemini.agent.wrapper.sh # Core wrapper script
    ├── gemini-parse.sh         # Response parser
    └── pre-commit.hook         # Git verification hook
```

## Hooks

The `.claude/settings.json` includes hooks that remind Claude to use Gemini:

- **UserPromptSubmit**: Before processing, Claude considers if Gemini should analyze first
- **Stop**: After completing work, Claude considers verifying changes with Gemini

## Claude Skill: Gemini Research

The skill at `.claude/skills/gemini-research/SKILL.md` teaches Claude:

- **When to use Gemini**: Files >100 lines, multi-file analysis, architecture review
- **How to invoke**: `./skills/gemini.agent.wrapper.sh -r [role] "query"`
- **Available roles**: reviewer, debugger, planner, security, auditor, plus custom roles
- **Response format**: Structured `## SUMMARY`, `## FILES`, `## ANALYSIS`, `## RECOMMENDATIONS`

## Usage Examples

Claude will automatically use these patterns based on the skill:

```bash
# Code review
./skills/gemini.agent.wrapper.sh -r reviewer -d "@src/" "Review the auth module"

# Bug tracing
./skills/gemini.agent.wrapper.sh -r debugger "Error at auth.ts:145"

# Security audit
./skills/gemini.agent.wrapper.sh -r security -d "@src/" "Security audit"

# Implementation-ready analysis
./skills/gemini.agent.wrapper.sh -t implement-ready -d "@src/" "Add user profiles"

# Post-implementation verification
./skills/gemini.agent.wrapper.sh -t verify --diff "Added password reset"
```

## Custom Roles

Add project-specific roles in `.gemini/roles/`:

| Role | File | Focus |
|------|------|-------|
| `kotlin-expert` | `.gemini/roles/kotlin-expert.md` | Kotlin/Android, coroutines |
| `typescript-expert` | `.gemini/roles/typescript-expert.md` | TypeScript type safety |
| `python-expert` | `.gemini/roles/python-expert.md` | Python async |
| `api-designer` | `.gemini/roles/api-designer.md` | REST API design |
| `database-expert` | `.gemini/roles/database-expert.md` | Query optimization |

## Wrapper Options

```
-d, --dir DIRS        Directories to include (@src/ @lib/)
-r, --role ROLE       Use role (built-in or custom)
-t, --template TMPL   Use template (feature, bug, verify, implement-ready, fix-ready)
--diff [TARGET]       Include git diff
--cache               Cache response
--estimate            Show token estimate
--validate            Validate response format
--summarize           Request compressed response
--dry-run             Show prompt without executing
--verbose             Show status messages
```

## Design Philosophy

This repository has one purpose: **making Gemini CLI a seamless research subagent for Claude Code**.

- **Gemini reads** (1M+ token context)
- **Claude implements** (based on Gemini's analysis)
- **Gemini verifies** (post-implementation review)

## License

MIT
