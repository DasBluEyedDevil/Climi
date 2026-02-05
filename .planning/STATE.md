# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-02-05)

**Core value:** Claude Code users can delegate any R&D task to Kimi K2.5 -- research, analysis, implementation, debugging, refactoring -- while Claude stays in the architect seat.
**Current focus:** v2.0 Autonomous Delegation — MCP Bridge, Hooks System, Enhanced SKILL.md

## Current Position

Phase: 10 of 11 (Enhanced SKILL.md)
Plan: 1 of 4 in current phase
Status: In progress
Last activity: 2026-02-05 — Completed 10-01-PLAN.md

Progress: [█████████████░░░░░░░░░░░░░░░░░░░░░░░░░░░] 38%

## Milestones

| Version | Status | Phases | Plans | Shipped |
|---------|--------|--------|-------|---------|
| v1.0 MVP | SHIPPED | 1-7 | 15 | 2026-02-05 |
| v2.0 | In Progress | TBD | TBD | - |

See: .planning/MILESTONES.md for details

## Accumulated Context

### Decisions

All v1.0 decisions archived in `.planning/milestones/v1.0-ROADMAP.md`.

Key decisions carried forward:
- Exit codes 10-13 for wrapper errors; 1-9 reserved for kimi CLI
- Analysis roles exclude: Shell, WriteFile, StrReplaceFile, SetTodoList, CreateSubagent, Task
- Bash resolution order: Git Bash > WSL > MSYS2 > Cygwin > PATH

**v2.0 Phase 8 decisions:**
| Phase | Decision | Rationale |
|-------|----------|-----------|
| 8-01 | Pure Bash MCP implementation (no SDK deps) | Minimize dependencies for CLI integration |
| 8-01 | jq required for all JSON operations | Prevent injection, ensure spec compliance |
| 8-01 | Protocol version 2025-11-25 | Current MCP specification |
| 8-02 | Configuration precedence: env > user config > defaults | Flexible deployment and local customization |
| 8-02 | Model validation with fallback to k2 | Prevent invalid model selections |
| 8-02 | 4 built-in analysis roles (general, security, performance, refactor) | Support different analysis contexts |
| 8-03 | Platform-specific stat commands (Linux/macOS/Windows) | Cross-platform file size detection |
| 8-03 | Binary file detection using 'file' command or null byte check | Skip binary files gracefully |
| 8-03 | Tool handlers validate required 'prompt' parameter | Fail fast on invalid tool calls |
| 8-03 | Prompt structure: system + files + context + task | Consistent prompt building across tools |
| 8-04 | All stdout must be valid JSON-RPC (no debug prints) | Protocol compliance |
| 8-04 | Logging to stderr only | Avoid protocol corruption |
| 8-04 | Single sequential request processing | Simple, predictable behavior |
| 8-04 | Tool errors return isError=true (not JSON-RPC error) | Distinguish protocol vs tool errors |
| 8-05 | CLI wrapper locates server via relative path | Works in dev and installed contexts |
| 8-05 | Setup helper manages ~/.kimi/mcp.json | Kimi CLI MCP client integration |
| 8-05 | Default config only copied if not exists | Preserve user configuration changes |

**v2.0 Phase 9 decisions:**
| Phase | Decision | Rationale |
|-------|----------|-----------|
| 9-01 | Project config (.kimi/hooks.json) > user config (~/.config/kimi/hooks.json) | Project-specific needs take priority |
| 9-01 | Hook-specific settings override global settings | Different hooks have different requirements |
| 9-01 | Bypass env var configurable (default: KIMI_HOOKS_SKIP) | Consistent naming but allows customization |
| 9-01 | Boolean validation accepts only "true"/"false" | Strict validation prevents ambiguity |
| 9-02 | Shared library approach for all hooks | Reduces duplication, ensures consistency |
| 9-02 | Hooks return 0 on skip (don't block git) | Git operations should not be blocked unnecessarily |
| 9-02 | Pre-commit stashes unstaged changes during auto-fix | Prevents conflicts with unstaged work |
| 9-02 | Post-checkout max_files limit prevents overload | Large branch switches could analyze hundreds of files |
| 9-02 | Pre-push still fails after auto-fix | User should review fixes before pushing |
| 9-03 | Global hooks use ~/.config/git/hooks/ | Git 2.9+ core.hooksPath support |
| 9-03 | Installation creates symlinks, not copies | Easy updates when hook scripts change |
| 9-03 | Existing hooks backed up before overwrite | Prevent data loss during installation |
| 9-03 | kimi-hooks delegates to kimi-hooks-setup | DRY principle for shared operations |
| 9-04 | Follow MCP bridge pattern for hooks installation | Consistency across components |
| 9-04 | Added logging abstraction for installer feedback | Cleaner code, consistent output |

**v2.0 Phase 10 decisions:**
| Phase | Decision | Rationale |
|-------|----------|-----------|
| 10-01 | K2 for backend files (.py, .js, .go, .rs, etc.) | Routine tasks need fast, efficient model |
| 10-01 | K2.5 for UI files (.tsx, .jsx, .css, .vue, etc.) | Creative/UI tasks benefit from stronger model |
| 10-01 | Test files (*.test.*, *.spec.*) force K2 | Tests are routine, not creative work |
| 10-01 | Component files (*component*) boost K2.5 score | Component creation is creative work |
| 10-01 | Default confidence threshold: 75% | Balances automation with accuracy |

### Pending Todos

None - v2.0 planning in progress.

### Blockers/Concerns

- jq runtime dependency: Must be installed for MCP server operation (documented in 08-01-SUMMARY.md)

## Session Continuity

Last session: 2026-02-05T18:00:53Z
Stopped at: Completed 10-01-PLAN.md (Phase 10, Plan 1)
Resume file: None

**Resumption notes:** Phase 10 (Enhanced SKILL.md) **IN PROGRESS**. Plan 1 complete:
- 10-01: Configuration and Classification ✓ (model-rules.json, task-classifier.sh)

Next: Plan 10-02 - Model Selection Engine with confidence scoring

## Archives

- `.planning/milestones/v1.0-ROADMAP.md` - Full phase details
- `.planning/milestones/v1.0-REQUIREMENTS.md` - All 39 requirements
- `.planning/milestones/v1.0-MILESTONE-AUDIT.md` - Audit report
