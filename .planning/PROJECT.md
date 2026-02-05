# Multi-Agent-Workflow

## What This Is

A Claude Code plugin that integrates Kimi CLI (Kimi Code) as a general-purpose research & development subagent. Claude serves as the Architect and coordinator — deciding strategy, delegating work, and reviewing results. Kimi serves as the autonomous R&D agent — researching, analyzing, writing code, running commands, and executing any delegated task.

## Core Value

Claude Code users can delegate any R&D task to Kimi K2.5 via simple slash commands — research, code analysis, implementation, debugging, refactoring — while Claude stays in the architect seat coordinating the work.

## Current State (v2.0 Shipped)

**Shipped:** 2026-02-05

**What's working:**
- MCP Bridge: Kimi exposed as 4 callable MCP tools (analyze, implement, refactor, verify) via JSON-RPC protocol
- Hooks System: Git pre-commit, post-checkout, and pre-push hooks auto-delegate coding tasks to Kimi
- Intelligent Model Selection: Automatic K2 vs K2.5 selection based on file types and task classification
- Cost Estimation: Token and cost estimation before delegation with configurable confidence thresholds
- Flexible Configuration: Global (~/.config/) and per-project (.kimi/) configuration with clear precedence rules
- Enhanced Documentation: Complete guides for MCP setup, hooks configuration, and model selection best practices
- All v1.0 features preserved: wrapper script, 7 agent roles, 6 templates, 4 slash commands, cross-platform installer

**Tech stack:**
- Bash (wrapper script, MCP server, hooks, installer)
- PowerShell (Windows shim)
- YAML (Kimi agent configurations)
- Markdown (system prompts, templates, documentation)
- JSON (MCP protocol, configuration files)

## Requirements

### Validated (v2.0)

- ✓ MCP Bridge: Kimi exposed as callable MCP tools for external systems — v2.0
- ✓ Hooks System: Auto-delegate hands-on coding tasks to Kimi with predefined hooks — v2.0
- ✓ Enhanced SKILL.md: Smarter triggers for autonomous delegation to preserve Claude tokens — v2.0
- ✓ Configuration: Per-project or global hook installation — v2.0
- ✓ Intelligent Model Selection: Automatic K2 vs K2.5 based on file type and task — v2.0
- ✓ Cost Estimation: Token and cost estimates before delegation — v2.0

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

- [ ] Custom hook creation API — v3.0
- [ ] IDE integration hooks (VSCode, IntelliJ) — v3.0
- [ ] CI/CD pipeline hooks — v3.0
- [ ] Streaming responses for long-running tasks — v3.0
- [ ] Multi-tool orchestration (chain Kimi calls) — v3.0
- [ ] Learn from user corrections to improve auto-delegation — v3.0

### Out of Scope

- Response caching — Kimi CLI handles its own session management
- Chat session history — Kimi has `--continue`/`--session` natively
- Batch mode — low usage, adds complexity
- Token estimation — not reliable across models
- Smart context search — Kimi reads the working directory natively
- Structured output schemas (JSON) — keep output as natural text for Claude
- Model fallback logic — Kimi handles provider errors
- Real-time collaboration — requires significant infrastructure
- Web UI for configuration — CLI-first approach
- Multi-user support — single-user developer tool
- Cloud-hosted MCP server — local-first design
- Token usage analytics — nice-to-have; focus on core features
- Hook marketplace/sharing — premature; establish core hooks first

## Context

**v2.0 shipped:** Full autonomous delegation system with MCP Bridge, Hooks System, and intelligent model selection. The system now automatically delegates routine coding tasks (refactoring, tests) to K2 and creative/UI tasks to K2.5, preserving Claude Code tokens for architecture and coordination.

**v1.0 shipped:** Full Kimi CLI integration replacing previous Gemini CLI wrapper. Kimi K2.5 offers better code analysis, native agent system (`--agent-file` YAML), and broader delegation model (R&D subagent, not just analyst).

**Target audience:** Claude Code users who want a second AI agent for delegated R&D work with automatic delegation for hands-on coding tasks.

## Constraints

- **CLI dependency**: Requires `kimi` CLI installed (`uv tool install kimi-cli`)
- **Platform**: Works on Windows (Git Bash + PowerShell), macOS, and Linux
- **Shell**: Wrapper is bash-compatible (Git Bash on Windows)
- **Agent file paths**: Kimi resolves `system_prompt_path` relative to agent YAML location
- **jq dependency**: Required for MCP server (JSON processing)
- **Git**: Hooks require Git 2.9+ for core.hooksPath support

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
| Pure Bash MCP implementation | Minimize dependencies for CLI integration | ✓ Good |
| Configuration precedence: env > user > defaults | Flexible deployment and local customization | ✓ Good |
| K2 for backend, K2.5 for UI files | Routine vs creative task optimization | ✓ Good |
| auto_model defaults to false | Backward compatibility preserved | ✓ Good |
| v2.0 features are additive | No breaking changes for existing users | ✓ Good |

---
*Last updated: 2026-02-05 after v2.0 milestone completion*
