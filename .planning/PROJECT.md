# Multi-Agent-Workflow

## What This Is

A Claude Code plugin that integrates Kimi CLI (Kimi Code) as a general-purpose research & development subagent. Claude serves as the Architect and coordinator — deciding strategy, delegating work, and reviewing results. Kimi serves as the autonomous R&D agent — researching, analyzing, writing code, running commands, and executing any delegated task.

## Core Value

Claude Code users can delegate any R&D task to Kimi K2.5 via simple slash commands — research, code analysis, implementation, debugging, refactoring — while Claude stays in the architect seat coordinating the work.

## Current State (v1.0 Shipped)

**Shipped:** 2026-02-05

**What's working:**
- Core wrapper script (`skills/kimi.agent.wrapper.sh`) with CLI detection, version checking, two-tier agent resolution
- 7 specialized agent roles: reviewer, security, auditor (analysis - read-only), debugger, refactorer, implementer, simplifier (action - full tools)
- 6 built-in templates: feature, bug, verify, architecture, implement-ready, fix-ready
- Git diff injection (`--diff`) and context file auto-loading (`.kimi/context.md`)
- 4 slash commands: `/kimi-analyze`, `/kimi-audit`, `/kimi-trace`, `/kimi-verify`
- Cross-platform distribution: install.sh, uninstall.sh, PowerShell shim
- Comprehensive README documentation

**Tech stack:**
- Bash (wrapper script, installer)
- PowerShell (Windows shim)
- YAML (Kimi agent configurations)
- Markdown (system prompts, templates, documentation)

## Requirements

### Validated (v1.0)

- ✓ Core wrapper script with CLI validation and role selection — v1.0
- ✓ Two-tier agent resolution (project-local → global) — v1.0
- ✓ 7 specialized agent roles with appropriate tool access — v1.0
- ✓ Template system with 6 built-in templates — v1.0
- ✓ Git diff injection and context file auto-loading — v1.0
- ✓ 4 Claude Code slash commands — v1.0
- ✓ SKILL.md and CLAUDE.md section template — v1.0
- ✓ Cross-platform installer with backup support — v1.0
- ✓ PowerShell shim for Windows — v1.0
- ✓ Comprehensive README documentation — v1.0

### Active

(None — awaiting v2.0 planning)

### Out of Scope

- Response caching — Kimi CLI handles its own session management
- Chat session history — Kimi has `--continue`/`--session` natively
- Batch mode — low usage, adds complexity
- Token estimation — not reliable across models
- Smart context search — Kimi reads the working directory natively
- Structured output schemas (JSON) — keep output as natural text for Claude
- Model fallback logic — Kimi handles provider errors

## Context

**v1.0 shipped:** Full Kimi CLI integration replacing previous Gemini CLI wrapper. Kimi K2.5 offers better code analysis, native agent system (`--agent-file` YAML), and broader delegation model (R&D subagent, not just analyst).

**Target audience:** Claude Code users who want a second AI agent for delegated R&D work.

## Constraints

- **CLI dependency**: Requires `kimi` CLI installed (`uv tool install kimi-cli`)
- **Platform**: Works on Windows (Git Bash + PowerShell), macOS, and Linux
- **Shell**: Wrapper is bash-compatible (Git Bash on Windows)
- **Agent file paths**: Kimi resolves `system_prompt_path` relative to agent YAML location

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Replace Gemini with Kimi | Better model (K2.5) + better CLI (native agents, --quiet mode) | ✓ Good |
| Kimi as R&D subagent, not just analyst | Full delegation model vs read-only analysis | ✓ Good |
| Use --agent-file for roles | Cleaner than prompt injection, uses Kimi natively | ✓ Good |
| Exit codes 10-13 for wrapper errors | Distinct from kimi CLI codes (1-9) | ✓ Good |
| Analysis roles exclude write tools | Security: reviewers can't modify code | ✓ Good |
| Bash resolution on Windows | Git Bash > WSL > MSYS2 > Cygwin > PATH | ✓ Good |
| Extended existing install.sh | Supports both Gemini and Kimi integrations | ✓ Good |

---
*Last updated: 2026-02-05 after v1.0 milestone shipped*
