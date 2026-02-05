# Roadmap: Multi-Agent-Workflow

## Overview

This roadmap delivers a Claude Code plugin that integrates Kimi CLI as an autonomous R&D subagent. The journey starts with a core wrapper script that can invoke Kimi with role-based agent files, builds out the full role library and prompt assembly features, adds Claude Code slash commands for seamless delegation, and finishes with cross-platform distribution. Each phase delivers a testable capability -- the wrapper works end-to-end after Phase 1, gains real agent personas in Phase 2, becomes a power tool in Phases 3-4, integrates into Claude's workflow in Phase 5, and ships to users in Phase 6.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [x] **Phase 1: Core Wrapper** - Bare Kimi CLI invocation with role selection and validation
- [x] **Phase 2: Agent Roles** - Full agent YAML files, system prompts, and tool access scoping
- [x] **Phase 3: Prompt Assembly** - Templates, git diff injection, and context file loading
- [ ] **Phase 4: Developer Experience** - Thinking mode, dry-run, verbose, and help output
- [ ] **Phase 5: Claude Code Integration** - Slash commands, SKILL.md, and CLAUDE.md delegation rules
- [ ] **Phase 6: Distribution** - Install/uninstall scripts, PowerShell shim, README, and version pinning

## Phase Details

### Phase 1: Core Wrapper
**Goal**: A working wrapper script that invokes Kimi CLI with a selected agent role and validates the CLI environment
**Depends on**: Nothing (first phase)
**Requirements**: WRAP-01, WRAP-02, WRAP-03, WRAP-08, WRAP-10, WRAP-12, WRAP-13
**Success Criteria** (what must be TRUE):
  1. User can run `kimi.agent.wrapper.sh -r reviewer "review this code"` and receive Kimi's analysis output
  2. Wrapper resolves agent files from project `.kimi/agents/` first, falling back to global install location
  3. Wrapper exits with a clear error message and install instructions if `kimi` CLI is not found
  4. Wrapper warns if Kimi CLI version is below the minimum supported version
  5. User can pass `-m <model>` and `-w <path>` flags through to Kimi CLI
**Plans**: 1 plan

Plans:
- [x] 01-01-PLAN.md -- Complete wrapper script with CLI validation, arg parsing, role resolution, invocation, and smoke tests

### Phase 2: Agent Roles
**Goal**: Users can delegate to specialized Kimi agents -- reviewers that only read, debuggers that can write and execute -- each with structured output
**Depends on**: Phase 1
**Requirements**: ROLE-01, ROLE-02, ROLE-03, ROLE-04, ROLE-05, ROLE-06, ROLE-07, ROLE-08, ROLE-09, ROLE-10, ROLE-11
**Success Criteria** (what must be TRUE):
  1. User can invoke any of the 7 roles (reviewer, security, auditor, debugger, refactorer, implementer, simplifier) by name via `-r <role>`
  2. Analysis roles (reviewer, security, auditor) cannot write files or execute shell commands -- tool access is restricted via `exclude_tools` in YAML
  3. Action roles (debugger, refactorer, implementer, simplifier) retain full tool access for autonomous work
  4. All roles produce structured output (SUMMARY/FILES/ANALYSIS/RECOMMENDATIONS sections)
  5. All agent YAML files use `extend: default` for Kimi-native inheritance
**Plans**: 3 plans in 3 waves

Plans:
- [x] 02-01-PLAN.md -- Create 3 analysis role agents (reviewer, security, auditor) with read-only tool access
- [x] 02-02-PLAN.md -- Create 4 action role agents (debugger, refactorer, implementer, simplifier) with full tool access
- [x] 02-03-PLAN.md -- Verify all 7 agent configurations work correctly (syntax, invocation, tool restrictions, output format)

### Phase 3: Prompt Assembly
**Goal**: Users can enrich Kimi invocations with templates, git diffs, and project context without manual prompt construction
**Depends on**: Phase 1
**Requirements**: WRAP-04, WRAP-05, WRAP-06, WRAP-07
**Success Criteria** (what must be TRUE):
  1. User can run `-t verify` and the verify template text is prepended to their prompt before Kimi receives it
  2. All 6 built-in templates (feature, bug, verify, architecture, implement-ready, fix-ready) exist and load correctly
  3. User can run `--diff` and the current `git diff` output is injected into the prompt context
  4. If `KimiContext.md` or `.kimi/context.md` exists in the project, its contents are automatically prepended to every prompt
**Plans**: TBD

Plans:
- [x] 03-01-PLAN.md -- Template-based prompt prepending with 6 built-in templates (feature, bug, verify, architecture, implement-ready, fix-ready)
- [x] 03-02-PLAN.md -- Git diff injection (--diff flag) and context file auto-loading (.kimi/context.md, KimiContext.md)
- [x] 03-03-PLAN.md -- Comprehensive verification of all prompt assembly features with documented test evidence

### Phase 4: Developer Experience
**Goal**: Users can debug wrapper behavior, preview commands, access help, and activate deep thinking mode
**Depends on**: Phase 1, Phase 3
**Requirements**: WRAP-09, WRAP-11, WRAP-14, WRAP-15
**Success Criteria** (what must be TRUE):
  1. User can run `--dry-run` and see the exact Kimi CLI command that would be executed, without executing it
  2. User can run `--verbose` and see detailed wrapper execution steps (argument parsing, file resolution, prompt assembly)
  3. User can run `-h` or `--help` and see documentation of all flags, roles, and templates
  4. User can pass `--thinking` and Kimi uses its extended thinking mode for deeper analysis
**Plans**: 2 plans in 1 wave (parallel)

Plans:
- [ ] 04-01-PLAN.md -- Enhanced help output with dynamic role/template enumeration and thinking flag documentation
- [ ] 04-02-PLAN.md -- Verbose mode and dry-run mode for debugging wrapper behavior

### Phase 5: Claude Code Integration
**Goal**: Claude Code users can delegate work to Kimi via slash commands, and Claude knows when and how to invoke Kimi autonomously
**Depends on**: Phase 1, Phase 2, Phase 3, Phase 4
**Requirements**: INTG-01, INTG-02, INTG-03, INTG-04, INTG-05, INTG-06
**Success Criteria** (what must be TRUE):
  1. User can type `/kimi-analyze`, `/kimi-audit`, `/kimi-trace`, or `/kimi-verify` in Claude Code and Kimi is invoked with the correct role/template
  2. A single SKILL.md (under 3,000 characters) teaches Claude when and how to invoke Kimi for research and delegation tasks
  3. A CLAUDE.md section template provides users with delegation rules (when to use Kimi vs handle directly)
**Plans**: TBD

Plans:
- [ ] 05-01: TBD
- [ ] 05-02: TBD

### Phase 6: Distribution
**Goal**: Users can install the entire plugin by cloning the repo and running one command, on any platform
**Depends on**: Phase 1, Phase 2, Phase 3, Phase 4, Phase 5
**Requirements**: DIST-01, DIST-02, DIST-03, DIST-04, DIST-05, DIST-06, DIST-07
**Success Criteria** (what must be TRUE):
  1. User can run `install.sh` and all wrapper scripts, agent files, slash commands, and skills are installed to the correct locations
  2. Installer supports global (`~/.claude/`), project-local, and custom target directories
  3. Installer checks for `kimi` CLI presence and provides actionable install instructions if missing
  4. Installer detects existing installation and offers backup before upgrading
  5. User can run `uninstall.sh` and all installed components are cleanly removed
  6. PowerShell shim (`kimi.ps1`) allows Windows users to invoke the wrapper from PowerShell
  7. README.md documents installation, quick start, all roles, architecture overview, and known-good Kimi CLI version
**Plans**: TBD

Plans:
- [ ] 06-01: TBD
- [ ] 06-02: TBD
- [ ] 06-03: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 1 -> 2 -> 3 -> 4 -> 5 -> 6

Note: Phase 3 (Prompt Assembly) depends only on Phase 1 and can be planned in parallel with Phase 2.

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Core Wrapper | 1/1 | Complete | 2026-02-04 |
| 2. Agent Roles | 3/3 | Complete | 2026-02-04 |
| 3. Prompt Assembly | 3/3 | Complete | 2026-02-05 |
| 4. Developer Experience | 0/2 | Not started | - |
| 5. Claude Code Integration | 0/TBD | Not started | - |
| 6. Distribution | 0/TBD | Not started | - |
