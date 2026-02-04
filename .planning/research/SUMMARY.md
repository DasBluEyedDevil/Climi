# Project Research Summary

**Project:** Kimi CLI Integration for Claude Code (R&D Subagent System)
**Domain:** Multi-agent development workflow with AI CLI orchestration
**Researched:** 2026-02-04
**Confidence:** HIGH

## Executive Summary

This project is fundamentally about creating a **thin orchestration layer** that positions Kimi CLI as Claude Code's autonomous R&D subagent. Unlike the previous Gemini wrapper (1060 lines of complex prompt engineering), this integration leverages Kimi CLI's native agent system, yielding a ~200-line wrapper that bridges two agentic systems rather than reimplementing one.

The recommended approach centers on **Kimi CLI v1.7.0** with `--quiet` mode for non-interactive invocation and `--agent-file` for native role management. The wrapper's sole responsibility is mapping user requests (via slash commands) to Kimi invocations with appropriate agent files, templates, and context injection. Kimi handles everything else: tool execution, session management, model selection, context management, and output formatting. This architectural decision trades control for simplicity and maintainability.

The primary risk is **Kimi CLI version instability**. The project has 847+ GitHub issues and demonstrated breaking changes between minor versions (v0.75-to-v0.78 replaced the execution engine, causing infinite loops). Mitigation: version pinning (`uv tool install kimi-cli==1.7.0`), startup version checks, and designing the wrapper to depend only on stable interfaces (`--quiet`, `--agent-file`, `-p`). Secondary risks include Windows PATH resolution after system updates, prompt injection via context files (mitigated by tool-scoped agent YAML files), and scope creep (hard 300-line budget enforced).

## Key Findings

### Recommended Stack

**Confidence: HIGH** (verified from official Kimi CLI docs, PyPI, and GitHub)

Kimi CLI v1.7.0 is the core dependency, installed via `uv tool install --python 3.13 kimi-cli`. The wrapper is pure Bash (4.0+ for cross-platform compatibility), with a PowerShell shim for Windows Git Bash resolution. No external dependencies beyond `kimi` and `git` (optional, for diff injection).

**Core technologies:**
- **Kimi CLI 1.7.0**: LLM analysis engine with 1T-param K2.5 model, native agent YAML system, `--quiet` mode for clean scripted output, `--agent-file` for role injection
- **Bash (POSIX-compatible 4.0+)**: Primary wrapper script (~200 lines target), proven cross-platform on macOS/Linux/Windows (Git Bash)
- **PowerShell 7.0+**: Windows entry point, thin shim (~45 lines, proven pattern from Gemini wrapper)
- **Python 3.13**: Kimi CLI runtime dependency (explicitly recommended in official docs)
- **uv (latest)**: Python tool installer, official installation method

**Critical flags for wrapper integration:**
- `--quiet`: Shortcut for `--print --output-format text --final-message-only` — clean text output, no TUI chrome
- `--agent-file PATH`: Load custom agent YAML file (native role system)
- `--prompt TEXT` / `-p`: Pass user prompt, non-interactive mode
- `--yolo` / `--yes`: Auto-approve (implied by `--quiet`)

**Key design decision:** The wrapper does NOT concatenate massive prompts or manage model selection. Kimi's agent system handles personas, output formatting, and tool access via YAML files with `extend: default` inheritance. The wrapper only handles template loading, git diff injection, context file loading, and role path resolution (project vs global).

### Expected Features

**Confidence: HIGH** (derived from Gemini wrapper analysis + Kimi CLI capabilities + Claude Code plugin patterns)

This is NOT just a large-context code analysis tool. Kimi is positioned as Claude's general-purpose R&D subagent with distinct role types:

**Analysis roles (read-only):** reviewer, auditor, security, explainer, onboarder
- Tool restriction via `exclude_tools` in agent YAML
- Cannot modify files or execute shell commands
- Safe for untrusted repositories

**Action roles (full tool access):** debugger, migrator, planner, refactorer
- Retain WriteFile, Shell, and other modification tools
- Used when Claude delegates autonomous implementation
- Requires trusted repository context

**Table stakes (users expect these):**
- 4 slash commands (`/kimi-analyze`, `/kimi-verify`, `/kimi-trace`, `/kimi-audit`)
- Role switching (`-r reviewer`, `-r planner`) without YAML knowledge
- 5-8 predefined agent files (reviewer, debugger, planner, security, explainer, auditor, documenter, onboarder)
- Diff injection (`--diff`) for verification workflows
- Context file loading (`KimiContext.md`)
- Cross-platform support (Bash + PowerShell shim)
- Non-interactive print mode (always `--quiet`)

**Differentiators (vs raw Kimi CLI):**
- 6 template files (feature, bug, verify, architecture, implement-ready, fix-ready) — pre-structured prompts
- Thinking mode toggle (`--think` flag passed to `--thinking`)
- Agent inheritance architecture (users extend shipped defaults via `extend:`)
- CLAUDE.md workflow instructions (auto-inject delegation rules)
- Dry-run mode (`--dry-run` shows constructed prompt without API call)
- Diff-aware context (`--diff-aware` only analyzes changed files)

**Anti-features (deliberately excluded):**
- Response caching (stale cache problem, 40+ lines in Gemini wrapper)
- Chat history management (Kimi's native `--session`/`--continue` suffice)
- Batch mode (shell loops serve this need)
- Token estimation (inaccurate, creates false confidence)
- Smart context search (Kimi has native Grep/Glob tools)
- Retry/fallback logic (Kimi has native `--max-retries-per-step`)
- jq dependency (no JSON processing needed with `--quiet` text output)

**Result:** Gemini wrapper's 1060 lines reduce to ~200-300 lines by eliminating features Kimi handles natively and anti-features that added complexity without value.

### Architecture Approach

**Confidence: HIGH** (based on official Kimi CLI agent docs + Claude Code plugin spec + existing codebase analysis)

**Thin Wrapper, Thick Native Agent** is the core architectural principle. The bash wrapper does minimal work:
1. Parse arguments (`-r role`, `-t template`, `-d dir`, `--diff`, `--think`)
2. Resolve agent file path (project `.kimi/agents/` then global fallback)
3. Load template markdown (if `-t` specified)
4. Load context file (`KimiContext.md` from project root or `.kimi/`)
5. Inject git diff (if `--diff` specified)
6. Assemble prompt: `context + template + diff + user_query`
7. Invoke: `kimi --agent-file AGENT --quiet -p "ASSEMBLED_PROMPT"`
8. Return stdout to Claude Code

**Major components:**
1. **Slash Commands** (`.claude/commands/kimi/*.md`) — User-facing entry points, instruct Claude how to invoke wrapper
2. **SKILL.md** (`.claude/skills/kimi-research/SKILL.md`) — Teaches Claude when/how to auto-invoke Kimi (one skill for entire plugin, under 3000 chars to stay within Claude's 15000-char skill budget)
3. **Wrapper Script** (`skills/kimi.agent.wrapper.sh`) — Thin orchestrator, ~200 lines
4. **PowerShell Shim** (`skills/kimi.ps1`) — Windows compatibility, ~45 lines
5. **Agent YAML Files** (`.kimi/agents/*.yaml`) — Kimi-native role definitions with tool access control
6. **System Prompt Files** (`.kimi/agents/prompts/*.md`) — Role personas and output formats
7. **Templates** (`.kimi/templates/*.md`) — Prompt patterns for common queries
8. **Context File** (`KimiContext.md`) — Project-specific rules auto-injected

**Key patterns:**
- **Two-tier role resolution:** Project `.kimi/agents/` overrides global `~/.claude/.kimi/agents/`
- **Template as prompt prefix:** Templates prepended to user query, not agent property (orthogonal concerns)
- **Agent tool scoping:** Analysis roles use `exclude_tools` to remove Shell/WriteFile; action roles retain full access
- **Context injection via prompt:** `KimiContext.md` loaded by wrapper and prepended, not referenced in agent YAML (per-project mutability)

**Anti-patterns to avoid:**
- Monolithic prompt construction in wrapper (defeats Kimi's agent system)
- Reimplementing Kimi features (session mgmt, model selection, retry logic)
- Hardcoded templates in bash (templates are external .md files)
- Output format injection at wrapper level (format instructions go in agent system prompts)
- Dual-mode invocation (PowerShell shim only resolves paths, zero logic)

### Critical Pitfalls

**Confidence: HIGH** (verified from Kimi CLI GitHub issues, Cyera Research Labs security disclosure, Claude Code issue tracker)

1. **Kimi CLI Version Instability (Breaking Changes)**
   - Evidence: v0.75-to-v0.78 replaced execution engine, causing infinite loops and 100% context usage
   - Prevention: Pin to `uv tool install kimi-cli==1.7.0`, version check on wrapper startup, CI test against 2+ versions, use only stable interfaces (`--quiet`, `--agent-file`)
   - Phase: Phase 1 (Core wrapper) — version check is first validation

2. **Windows PATH Loss After System Updates**
   - Evidence: KB5078127 update (Jan 2026) broke `kimi` PATH on Windows; `~/.local/bin` not standard Windows location
   - Prevention: Resolve `kimi` binary explicitly from `~/.local/bin`, `$(python -m site --user-base)/bin`, and uv tool dir; provide `KIMI_PATH` env var override; actionable error messages
   - Phase: Phase 1 (Core wrapper) + Phase 4 (Install script)

3. **Over-Engineering the Wrapper (Scope Creep to 1060 Lines)**
   - Evidence: Existing Gemini wrapper has caching (40 lines), chat history (40 lines), batch mode (35 lines), retry/fallback (65 lines), token estimation (15 lines), context hashing (20 lines), spinners (30 lines) — all anti-features
   - Prevention: Hard 300-line budget; before adding ANY feature, ask "Does Kimi handle this natively?"; maintain OUT_OF_SCOPE.md; template and role systems are ONLY complex features
   - Phase: All phases — continuous discipline

4. **Agent File Path Resolution Surprises**
   - Evidence: Kimi's `system_prompt_path` is relative to YAML file location, NOT CWD; moving agent files to different directory breaks prompt references
   - Prevention: Keep YAML + prompt in consistent structure (agents/role.yaml references agents/prompts/role.md); test from both global and project install paths; verify prompt existence after install
   - Phase: Phase 2 (Role/Agent system)

5. **Prompt Injection via Context Files**
   - Evidence: Cyera Research Labs disclosed command injection in Gemini CLI via crafted repository files; `--quiet` implies `--yolo` (auto-approve), enabling write/shell ops
   - Prevention: NEVER use `--quiet` for action roles; analysis roles use `exclude_tools` to remove Shell/WriteFile; add `--no-context` flag; limit context file size to 50KB; document trust model
   - Phase: Phase 1 (Context loading) + Phase 2 (Agent tools)

6. **Claude Code Skill Budget Overflow (15,000 chars)**
   - Evidence: Issue #17271 (skill namespace bug), #16900 (skills vs commands confusion); 5 skills × 4000 chars = 20,000 chars exceeds budget
   - Prevention: ONE SKILL.md for entire plugin (<3000 chars); separate slash commands for user invocation; check budget with `/context` after install
   - Phase: Phase 3 (Slash commands and Claude Code integration)

## Implications for Roadmap

Based on research, suggested phase structure:

### Phase 1: Foundation (Core Wrapper + Agent Infrastructure)
**Rationale:** The wrapper and agent files are co-dependent. The wrapper resolves agent paths; agent files define the behavior the wrapper invokes. Must be built together to validate Kimi CLI interface assumptions.

**Delivers:**
- Core bash wrapper script with arg parsing, role resolution, template loading, context injection, diff injection, Kimi invocation
- 8 agent YAML files (reviewer, debugger, planner, security, auditor, explainer, migrator, documenter) with corresponding system prompt .md files
- 6 template files (feature, bug, verify, architecture, implement-ready, fix-ready)
- KimiContext.md template
- Dry-run mode for debugging

**Addresses (from FEATURES.md):**
- Role switching (`-r role`)
- Template system (`-t template`)
- Context file loading
- Diff injection (`--diff`)
- Non-interactive print mode
- Error handling and validation

**Avoids (from PITFALLS.md):**
- Pitfall 1: Version check on startup (`kimi --version` parse and range validation)
- Pitfall 2: Binary path resolution (check `command -v kimi`, `~/.local/bin/kimi`, uv tool dir)
- Pitfall 3: Hard 300-line budget, no features beyond template/role/context/diff
- Pitfall 4: Test agent file resolution from both global and project paths
- Pitfall 5: Tool scoping in agent YAML (`exclude_tools` for analysis roles)

**Research flag:** LOW — Kimi CLI interface is well-documented. Skip `/gsd:research-phase`.

---

### Phase 2: Cross-Platform Compatibility (Windows + macOS)
**Rationale:** The wrapper from Phase 1 works on Linux. Phase 2 ensures it works on Windows (PowerShell shim + Git Bash) and macOS (bash 3.x constraints, BSD vs GNU tools).

**Delivers:**
- PowerShell shim (`kimi.ps1`) that resolves bash path and delegates
- Bash 3.x compatibility fixes (no associative arrays, no `${var,,}`, no `readarray`)
- Windows path separator handling
- macOS BSD tool compatibility (no `realpath`, stat differences)

**Addresses (from FEATURES.md):**
- Cross-platform support (Windows Git Bash + PowerShell + macOS bash 3.x + Linux)

**Avoids (from PITFALLS.md):**
- Pitfall 2: Windows PATH resolution in PowerShell shim
- Dual-mode invocation anti-pattern (shim is thin delegator only)

**Research flag:** LOW — PowerShell shim pattern proven in Gemini wrapper (45 lines).

---

### Phase 3: Claude Code Integration (Slash Commands + SKILL.md)
**Rationale:** Once the wrapper interface is stable (Phase 1) and cross-platform (Phase 2), Claude Code integration can be finalized. Slash commands depend on knowing the exact wrapper flags and roles available.

**Delivers:**
- 4 slash commands (`.claude/commands/kimi/kimi-analyze.md`, `kimi-verify.md`, `kimi-trace.md`, `kimi-audit.md`)
- ONE SKILL.md (`.claude/skills/kimi-research/SKILL.md`) under 3000 chars covering all roles and modes
- CLAUDE.md update with delegation rules (when to invoke Kimi)

**Addresses (from FEATURES.md):**
- Slash commands (table stakes)
- CLAUDE.md workflow instructions (differentiator)

**Avoids (from PITFALLS.md):**
- Pitfall 6: Single SKILL.md under 3000 chars (not separate skills per command)
- Skill budget overflow (verify with `/context` after install)

**Research flag:** LOW — Claude Code plugin format is standard (official docs + existing Gemini commands).

---

### Phase 4: Distribution and Installation
**Rationale:** All components must be complete and tested before packaging. The installer's file manifest depends on knowing every file from Phases 1-3.

**Delivers:**
- `install.sh` (global, project, or custom install target)
- `uninstall.sh` (clean removal)
- README.md with usage instructions and known-good Kimi CLI version
- Documentation (integration guide, role customization, template authoring)

**Addresses (from FEATURES.md):**
- Install/uninstall scripts (table stakes)
- Error handling (validate kimi binary exists, check version)

**Avoids (from PITFALLS.md):**
- Pitfall 1: Document minimum/maximum tested Kimi CLI versions; pin in install instructions
- Pitfall 2: Validate `kimi` binary path during install; persist to config or env var

**Research flag:** LOW — Install pattern established in Gemini wrapper.

---

### Phase 5: Polish and Enhancements (Post-MVP)
**Rationale:** Core workflow must be validated before adding convenience features. These are nice-to-haves that depend on user feedback.

**Delivers:**
- Thinking mode toggle (`--think` flag passed to `--thinking`)
- Diff-aware context (`--diff-aware` analyzes only changed files)
- Custom template directory support (`.kimi/templates/` alongside built-ins)
- Verbose mode (`--verbose` for human debugging)

**Addresses (from FEATURES.md):**
- Thinking mode toggle (differentiator)
- Diff-aware context (differentiator)
- Custom template directory (differentiator)
- Verbose/quiet toggle (differentiator)

**Research flag:** LOW — All pass-through flags or simple file loading patterns.

---

### Phase Ordering Rationale

1. **Phase 1 before Phase 3:** Slash commands cannot be finalized until the wrapper interface is stable. Chicken-and-egg problem resolved by building wrapper first.

2. **Phase 2 parallel to Phase 1:** Cross-platform work can start as soon as wrapper structure exists. PowerShell shim developed independently from wrapper logic.

3. **Phase 3 depends on Phases 1+2:** Claude Code integration is the final surface. It must work cross-platform, so Phase 2 must be complete.

4. **Phase 4 last:** Installer cannot be written until the complete file manifest is known.

5. **Phase 5 deferred:** These are enhancements, not blockers. User feedback from Phases 1-4 deployment informs priority.

**Dependency insight from architecture research:** The build order (agent files → wrapper → Claude integration → installer) maps cleanly to phases. Agent files and templates have no code dependencies, so they can be built and tested independently (`kimi --agent-file agents/reviewer.yaml --quiet -p "test"`). This informs Phase 1 structure: agent files are the first deliverable, validated before wrapper logic is written.

**Pitfall mitigation insight:** Pitfalls 1-3 must be addressed in Phase 1 because they are foundational (version stability, binary discovery, scope discipline). Pitfall 4 is Phase 2 (agent file resolution). Pitfall 5 is split (tool scoping in Phase 1, context loading safeguards in Phase 2). Pitfall 6 is Phase 3 (skill budget).

### Research Flags

**Phases likely needing deeper research during planning:**
- None. All phases have well-documented patterns. Kimi CLI official docs cover agent YAML format, command flags, and installation. Claude Code plugin spec is standard. PowerShell shim pattern proven in Gemini wrapper.

**Phases with standard patterns (skip research-phase):**
- **Phase 1:** Kimi CLI interface verified from official docs and GitHub
- **Phase 2:** Cross-platform bash patterns are well-established
- **Phase 3:** Claude Code plugin format documented at code.claude.com/docs
- **Phase 4:** Install script pattern exists in Gemini wrapper
- **Phase 5:** Pass-through flags, no novel integration

**Unknown unknowns to watch for:**
- Kimi CLI breaking changes in future versions (mitigated by version pinning, but monitor release notes)
- Claude Code skill system changes (post-v2.1.1 namespace bugs suggest instability; verify slash command discovery after Claude updates)

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Kimi CLI v1.7.0 verified from PyPI, official docs, GitHub. `--quiet` and `--agent-file` confirmed in command reference. Python 3.13 requirement explicit in docs. |
| Features | HIGH | Table stakes derived from Gemini wrapper user expectations. Differentiators based on Kimi's native capabilities (agent inheritance, thinking mode). Anti-features validated by Gemini wrapper's 1060-line complexity. |
| Architecture | HIGH | Thin wrapper pattern validated by official agent docs (YAML + system_prompt_path). Component boundaries verified from Claude Code plugin spec and Kimi CLI architecture. |
| Pitfalls | HIGH | Pitfalls 1-2 verified from Kimi CLI GitHub issues (#643, #748, #800). Pitfall 3 observed in existing codebase. Pitfall 4 confirmed in agent docs. Pitfall 5 from Cyera Labs security research. Pitfall 6 from Claude Code issues (#17271, #16900). |

**Overall confidence:** HIGH

### Gaps to Address

**Gap 1: Exact default model name after Kimi Code OAuth login**
- Research finding: Not publicly documented. Config.toml is auto-populated during `/login`.
- Handling: Do NOT hardcode model names. Use `--model` flag as optional override. Document that users configure their preferred model via `/login` or config.toml.
- Impact: LOW — wrapper does not need to know model names.

**Gap 2: `--quiet` flag availability in versions before 1.7.0**
- Research finding: `--quiet` referenced in DeepWiki and kimi-cli.com command reference, but exact version it was introduced is unclear.
- Handling: Test with `kimi --quiet --prompt "hello"` during Phase 1. If missing, fall back to explicit `--print --output-format text --final-message-only`.
- Impact: MEDIUM — affects version pinning strategy.

**Gap 3: Kimi K2.5 model identifier in config.toml**
- Research finding: Likely `kimi-k2.5` but not confirmed from CLI docs directly.
- Handling: Inspect `~/.kimi/config.toml` after `/login` during Phase 1 testing. Document observed model identifier.
- Impact: LOW — affects documentation only, not wrapper logic.

**Validation strategy:** All gaps are resolvable via Phase 1 testing. None block design decisions.

## Sources

### Primary (HIGH confidence)
- [Kimi CLI Official Documentation](https://moonshotai.github.io/kimi-cli/en/) — getting started, agent system, skills, configuration, slash commands, command reference
- [Kimi CLI GitHub Repository](https://github.com/MoonshotAI/kimi-cli) — README, AGENTS.md, issue tracker (847+ issues)
- [Kimi CLI PyPI](https://pypi.org/project/kimi-cli/) — version 1.7.0, release dates, Python requirement
- [Kimi CLI Command Reference](https://www.kimi-cli.com/en/reference/kimi-command.html) — complete flag list including `--quiet`, `--agent-file`, `-p`
- [Claude Code Plugins Reference](https://code.claude.com/docs/en/plugins-reference) — plugin.json manifest, commands/, skills/, hooks
- [Claude Code Skills Documentation](https://code.claude.com/docs/en/skills) — SKILL.md format, 15,000-char budget
- [Claude Code Slash Commands](https://code.claude.com/docs/en/slash-commands) — command format and discovery
- Existing codebase: `C:\Users\dasbl\Multi-Agent-Workflow\skills\gemini.agent.wrapper.sh` (1060 lines, direct analysis)
- Existing codebase: `C:\Users\dasbl\Multi-Agent-Workflow\.planning\codebase\ARCHITECTURE.md` (current system mapping)
- PROJECT.md: `C:\Users\dasbl\Multi-Agent-Workflow\.planning\PROJECT.md` (requirements source of truth)

### Secondary (MEDIUM confidence)
- [DeepWiki: Kimi CLI Architecture](https://deepwiki.com/MoonshotAI/kimi-cli) — architecture overview, CLI flags
- [DeepWiki: Command-Line Options Reference](https://deepwiki.com/MoonshotAI/kimi-cli/2.3-command-line-options-reference) — comprehensive flag reference
- [Kimi CLI Technical Deep Dive](https://llmmultiagents.com/en/blogs/kimi-cli-technical-deep-dive) — architecture details
- [Awesome Claude Code Plugins](https://github.com/ccplugins/awesome-claude-code-plugins) — plugin ecosystem patterns
- [Claude Code Plugin Lessons (Pierce Lamb)](https://pierce-lamb.medium.com/what-i-learned-while-building-a-trilogy-of-claude-code-plugins-72121823172b) — plugin best practices
- [Unix/BASH Agent Philosophy](https://thenewstack.io/the-key-to-agentic-success-let-unix-bash-lead-the-way/) — minimal design validation
- [Avoid Load-bearing Shell Scripts (Ben Congdon)](https://benjamincongdon.me/blog/2023/10/29/Avoid-Load-bearing-Shell-Scripts/) — scope creep antipattern
- [Cyera Research Labs: Prompt injection in Gemini CLI](https://www.cyera.com/research-labs/cyera-research-labs-discloses-command-prompt-injection-vulnerabilities-in-gemini-cli) — security vulnerability class

### Tertiary (LOW confidence, requires validation)
- [Kimi K2.5 with Claude Code (Joe Njenga)](https://medium.com/@joe.njenga/i-tested-kimi-k2-5-with-claude-code-1-trillion-parameters-8x-cheaper-than-opus-8d4f9e9c7b4d) — integration examples
- [Multi-Model Claude Code (Rakesh Tembhurne)](https://rakesh.tembhurne.com/blog/ai-tools/extend-claude-code-multiple-models-complete-guide) — multi-model patterns
- [Kimi K2.5 HuggingFace](https://huggingface.co/moonshotai/Kimi-K2.5) — model specs
- [Kimi K2.5 Announcement (TechCrunch)](https://techcrunch.com/2026/01/27/chinas-moonshot-releases-a-new-open-source-model-kimi-k2-5-and-a-coding-agent/) — release context

### Verified Pitfall Evidence
- [GitHub issue #643](https://github.com/MoonshotAI/kimi-cli/issues/643) — v0.75-to-v0.78 performance regression
- [GitHub issue #748](https://github.com/MoonshotAI/kimi-cli/issues/748) — install script does not update Kimi CLI
- [GitHub issue #800](https://github.com/MoonshotAI/kimi-cli/issues/800) — VSCode plugin "CLI Not Found" after Windows update
- [Claude Code issue #17271](https://github.com/anthropics/claude-code/issues/17271) — plugin skills namespace bug
- [Claude Code issue #16900](https://github.com/anthropics/claude-code/issues/16900) — skills vs commands confusion post-v2.1.1
- [Kimi CLI Troubleshooting (DeepWiki)](https://deepwiki.com/MoonshotAI/kimi-cli/12-troubleshooting) — platform-specific issues

---
*Research completed: 2026-02-04*
*Ready for roadmap: yes*
