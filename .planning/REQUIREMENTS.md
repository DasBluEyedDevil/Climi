# Requirements: Multi-Agent-Workflow

**Defined:** 2026-02-04
**Core Value:** Claude Code users can delegate any R&D task to Kimi K2.5 -- research, analysis, implementation, debugging, refactoring -- while Claude stays in the architect seat.

## v1 Requirements

### Core Wrapper

- [ ] **WRAP-01**: Wrapper script (`kimi.agent.wrapper.sh`) invokes Kimi CLI in `--quiet` mode with `--agent-file` and `--prompt` flags
- [ ] **WRAP-02**: Role selection via `-r <role>` flag maps to `.kimi/agents/<role>.yaml` file
- [ ] **WRAP-03**: Two-tier role resolution: project `.kimi/agents/` first, then global install location
- [ ] **WRAP-04**: Template system via `-t <template>` flag prepends template text to user prompt
- [ ] **WRAP-05**: Built-in templates: feature, bug, verify, architecture, implement-ready, fix-ready
- [ ] **WRAP-06**: Git diff injection via `--diff [TARGET]` captures `git diff` output and prepends to prompt
- [ ] **WRAP-07**: Context file injection: auto-loads `KimiContext.md` or `.kimi/context.md` and prepends to prompt
- [ ] **WRAP-08**: Model selection pass-through via `-m <model>` flag
- [ ] **WRAP-09**: Thinking mode pass-through via `--thinking` flag
- [ ] **WRAP-10**: Working directory pass-through via `-w <path>` flag
- [ ] **WRAP-11**: Dry-run mode (`--dry-run`) shows constructed command without executing
- [ ] **WRAP-12**: Kimi CLI presence check on startup with helpful install instructions on failure
- [ ] **WRAP-13**: Kimi CLI version check on startup (warn if below minimum supported version)
- [ ] **WRAP-14**: Verbose mode (`--verbose`) for debugging wrapper behavior
- [ ] **WRAP-15**: Usage/help output (`-h`/`--help`) documenting all flags and roles

### Agent Roles

Analysis roles (read-only -- `Shell`, `WriteFile`, `StrReplaceFile` excluded):

- [ ] **ROLE-01**: `reviewer` agent -- code review with structured findings (SUMMARY/FILES/ANALYSIS/RECOMMENDATIONS)
- [ ] **ROLE-02**: `security` agent -- security vulnerability analysis and OWASP compliance checks
- [ ] **ROLE-03**: `auditor` agent -- code quality, architecture conformance, and best practices audit

Action roles (full tool access -- can read, write, execute):

- [ ] **ROLE-04**: `debugger` agent -- investigate bugs, trace execution paths, propose and apply fixes
- [ ] **ROLE-05**: `refactorer` agent -- restructure code while preserving behavior, improve patterns
- [ ] **ROLE-06**: `implementer` agent -- build new features from specifications and requirements
- [ ] **ROLE-07**: `simplifier` agent -- reduce complexity, remove dead code, consolidate abstractions

Each role is a YAML agent file + markdown system prompt:

- [ ] **ROLE-08**: All agent YAML files use `extend: default` for Kimi native inheritance
- [ ] **ROLE-09**: All agent system prompts use structured output format (SUMMARY/FILES/ANALYSIS/RECOMMENDATIONS)
- [ ] **ROLE-10**: Analysis roles explicitly exclude write/shell tools via `exclude_tools`
- [ ] **ROLE-11**: Action roles retain full default toolset

### Claude Code Integration

- [ ] **INTG-01**: `/kimi-analyze` slash command -- delegate code analysis to Kimi with reviewer role
- [ ] **INTG-02**: `/kimi-audit` slash command -- delegate code audit to Kimi with auditor role
- [ ] **INTG-03**: `/kimi-trace` slash command -- delegate execution tracing/debugging to Kimi with debugger role
- [ ] **INTG-04**: `/kimi-verify` slash command -- delegate post-change verification to Kimi with verify template
- [ ] **INTG-05**: SKILL.md defining the Kimi integration skill (under 3,000 chars per Claude Code budget)
- [ ] **INTG-06**: CLAUDE.md section template with delegation rules (when to use Kimi vs handle directly)

### Distribution

- [ ] **DIST-01**: `install.sh` supports global (~/.claude/), project, and custom target directories
- [ ] **DIST-02**: `install.sh` checks prerequisites (kimi CLI, jq optional, git optional)
- [ ] **DIST-03**: `install.sh` detects existing installation and offers backup before upgrade
- [ ] **DIST-04**: `uninstall.sh` cleanly removes all installed components
- [ ] **DIST-05**: PowerShell shim (`kimi.ps1`) resolves bash path on Windows and delegates
- [ ] **DIST-06**: README.md with installation, quick start, role descriptions, architecture overview
- [ ] **DIST-07**: Version pinning: install script records minimum Kimi CLI version for compatibility

## v2 Requirements

### Enhanced Roles

- **ROLE-V2-01**: `planner` agent -- create implementation plans from requirements
- **ROLE-V2-02**: `documenter` agent -- generate documentation from code
- **ROLE-V2-03**: `onboarder` agent -- explain codebase to new developers
- **ROLE-V2-04**: `api-designer` agent -- design API interfaces and contracts
- **ROLE-V2-05**: Custom role creation guide -- users can create their own agent YAML files

### Advanced Features

- **ADV-01**: Thinking mode toggle in slash commands
- **ADV-02**: Diff-aware context (only include files changed in current branch)
- **ADV-03**: Custom template support (user-defined templates in `.kimi/templates/`)
- **ADV-04**: Session continuation (leverage Kimi's `--session` for multi-turn workflows)
- **ADV-05**: MCP bridge (expose Kimi capabilities as MCP tools for Claude)
- **ADV-06**: Hooks integration (pre/post Kimi invocation hooks for Claude Code)

## Out of Scope

| Feature | Reason |
|---------|--------|
| Response caching | Kimi CLI has native session management; wrapper caching adds complexity without value |
| Chat session history | Kimi has `--continue`/`--session` natively; wrapper shouldn't replicate |
| Batch mode | Low usage in Gemini wrapper; adds complexity |
| Token estimation | Not reliable across models; users have Kimi's own tooling |
| Smart context search (grep-based) | Kimi reads the working directory natively with its own tools |
| Structured output schemas (JSON) | Keep output as natural text for Claude consumption |
| Model fallback logic | Kimi handles provider errors internally |
| Response validation | Over-engineering; trust Kimi's output |
| Color output in wrapper | Kimi output goes to Claude, not human eyes; colors are noise |
| Log file support | Unnecessary complexity; use `--verbose` for debugging |
| jq dependency | Previous wrapper required jq for JSON; new wrapper doesn't need it |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| WRAP-01 | Phase 1 | Pending |
| WRAP-02 | Phase 1 | Pending |
| WRAP-03 | Phase 1 | Pending |
| WRAP-04 | Phase 3 | Pending |
| WRAP-05 | Phase 3 | Pending |
| WRAP-06 | Phase 3 | Pending |
| WRAP-07 | Phase 3 | Pending |
| WRAP-08 | Phase 1 | Pending |
| WRAP-09 | Phase 4 | Pending |
| WRAP-10 | Phase 1 | Pending |
| WRAP-11 | Phase 4 | Pending |
| WRAP-12 | Phase 1 | Pending |
| WRAP-13 | Phase 1 | Pending |
| WRAP-14 | Phase 4 | Pending |
| WRAP-15 | Phase 4 | Pending |
| ROLE-01 | Phase 2 | Complete |
| ROLE-02 | Phase 2 | Complete |
| ROLE-03 | Phase 2 | Complete |
| ROLE-04 | Phase 2 | Complete |
| ROLE-05 | Phase 2 | Complete |
| ROLE-06 | Phase 2 | Complete |
| ROLE-07 | Phase 2 | Complete |
| ROLE-08 | Phase 2 | Complete |
| ROLE-09 | Phase 2 | Complete |
| ROLE-10 | Phase 2 | Complete |
| ROLE-11 | Phase 2 | Complete |
| INTG-01 | Phase 5 | Pending |
| INTG-02 | Phase 5 | Pending |
| INTG-03 | Phase 5 | Pending |
| INTG-04 | Phase 5 | Pending |
| INTG-05 | Phase 5 | Pending |
| INTG-06 | Phase 5 | Pending |
| DIST-01 | Phase 6 | Pending |
| DIST-02 | Phase 6 | Pending |
| DIST-03 | Phase 6 | Pending |
| DIST-04 | Phase 6 | Pending |
| DIST-05 | Phase 6 | Pending |
| DIST-06 | Phase 6 | Pending |
| DIST-07 | Phase 6 | Pending |

**Coverage:**
- v1 requirements: 39 total
- Mapped to phases: 39
- Unmapped: 0

---
*Requirements defined: 2026-02-04*
*Last updated: 2026-02-04 after Phase 2 completion*
