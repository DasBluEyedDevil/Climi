# Multi-Agent-Workflow

## What This Is

A Claude Code plugin that integrates Kimi CLI (Kimi Code) as a "context companion" for large-scale code analysis. Kimi reads and analyzes code ("The Eyes"), Claude implements ("The Hands"). Replaces a previous Gemini CLI integration with a fresh design that leverages Kimi CLI's native agent system, delivering a cleaner, more capable workflow.

## Core Value

Claude Code users can delegate large-context code analysis to Kimi K2.5 via simple slash commands and get structured, actionable intelligence back — without leaving their Claude Code session.

## Requirements

### Validated

- ✓ Existing repo structure with install/uninstall scripts — existing
- ✓ Slash command integration pattern for Claude Code — existing
- ✓ Role-based analysis (reviewer, debugger, planner, security, etc.) — existing
- ✓ Template-based queries (feature, bug, verify, architecture) — existing
- ✓ PowerShell shim for Windows compatibility — existing
- ✓ Context file injection for project-specific rules — existing

### Active

- [ ] Core wrapper script (`kimi.agent.wrapper.sh`) using Kimi CLI's `--quiet`/`--print` mode for non-interactive analysis
- [ ] Role system using Kimi's native `--agent-file` (YAML agent definitions with markdown system prompts)
- [ ] Template system for common query patterns (feature, bug, verify, architecture, implement-ready, fix-ready)
- [ ] Git diff injection (`--diff` flag to include changed files in analysis context)
- [ ] Context file injection (`KimiContext.md` auto-loaded into queries)
- [ ] Slash commands for Claude Code (`/kimi-analyze`, `/kimi-audit`, `/kimi-trace`, `/kimi-verify`)
- [ ] Installer script that checks for `kimi` CLI, installs agent files, slash commands, and context file
- [ ] Uninstaller script that cleanly removes all installed components
- [ ] PowerShell shim (`kimi.ps1`) for Windows users running from PowerShell
- [ ] Agent files for all 15 roles: reviewer, debugger, planner, security, auditor, explainer, migrator, documenter, dependency-mapper, onboarder, api-designer, database-expert, kotlin-expert, typescript-expert, python-expert
- [ ] CLAUDE.md section template for users to add Kimi integration instructions to their projects
- [ ] README and documentation suitable for public release

### Out of Scope

- Response caching — Kimi CLI handles its own session management; wrapper-level caching adds complexity without clear value
- Chat session history — Kimi has `--continue`/`--session` natively
- Batch mode — low usage, adds complexity
- Token estimation — not reliable across models, users have Kimi's own tooling
- Smart context search (grep-based file discovery) — Kimi's agent reads the working directory natively
- Structured output schemas (JSON formatting) — keep output as natural text for Claude consumption
- Model fallback logic — Kimi handles provider errors; wrapper shouldn't second-guess it

## Context

**Previous implementation:** Gemini CLI wrapper with ~1060 lines of bash handling roles, templates, caching, chat history, batch mode, smart context, structured output, retry/fallback, and more. Overly complex because Gemini CLI lacked native agent/role support — everything had to be injected via prompt construction.

**Why Kimi:** Kimi K2.5 (released Jan 27, 2026) offers better code analysis results than Gemini and a CLI with native agent system (`--agent-file` YAML), `--quiet` mode for clean non-interactive output, built-in variables (`${KIMI_WORK_DIR}`, `${KIMI_NOW}`), and agent inheritance (`extend: default`). Most of what the old wrapper did manually is now handled natively.

**Kimi CLI key interface points:**
- Non-interactive: `kimi --quiet -p "prompt"` or `kimi --print --final-message-only -p "prompt"`
- Custom agent: `kimi --agent-file ./agents/reviewer.yaml --quiet -p "prompt"`
- Model selection: `kimi -m kimi-k2.5 --quiet -p "prompt"` (verify exact model name at implementation time)
- Working directory: `kimi -w /path/to/project --quiet -p "prompt"`
- Auto-approve: `--quiet` implies `--yolo`
- Thinking mode: `--thinking` for deeper analysis

**Agent file format (YAML):**
```yaml
version: 1
agent:
  extend: default
  name: reviewer
  system_prompt_path: ./prompts/reviewer.md
  exclude_tools:
    - "kimi_cli.tools.shell:Shell"  # read-only roles don't need shell
```

**Target audience:** Claude Code users who want a second AI for large-context code reading and analysis. Should be installable by someone who clones the repo and runs `install.sh`.

## Constraints

- **CLI dependency**: Requires `kimi` CLI installed (`uv tool install kimi-cli`)
- **Platform**: Must work on Windows (Git Bash + PowerShell), macOS, and Linux
- **Shell**: Wrapper must be bash-compatible (Git Bash on Windows)
- **Model versions**: Must verify exact Kimi model names via web search before hardcoding — model naming changes frequently
- **Agent file paths**: Kimi resolves `system_prompt_path` relative to the agent YAML file location
- **No Python dependency in wrapper**: The wrapper itself is bash/PowerShell — Kimi CLI is the Python component

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Replace Gemini with Kimi | Better model (K2.5) + better CLI (native agents, --quiet mode) | — Pending |
| Use --agent-file for roles | Cleaner than prompt injection, uses Kimi natively, each role is a YAML + markdown pair | — Pending |
| Fresh approach over 1:1 port | Most Gemini wrapper features are handled natively by Kimi CLI; simpler wrapper is better | — Pending |
| Minimal feature set | Roles, templates, diff injection, context file. Drop caching/chat/batch/estimation. | — Pending |
| Published plugin quality | README, installer, clean code — others can use this | — Pending |

---
*Last updated: 2026-02-04 after initialization*
