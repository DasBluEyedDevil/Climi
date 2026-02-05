# Roadmap: Multi-Agent-Workflow v2.0

**Milestone:** v2.0 Autonomous Delegation  
**Goal:** Enable aggressive autonomous delegation by exposing Kimi as MCP tools and auto-invoking it for hands-on coding tasks, preserving Claude Code tokens for architecture and coordination.  
**Created:** 2026-02-05  
**Phases:** 8-11 (4 phases)

---

## Phase Overview

| Phase | Name | Goal | Requirements | Success Criteria |
|-------|------|------|--------------|------------------|
| 8 | MCP Bridge | Expose Kimi as callable MCP tools | MCP-01 to MCP-09, CONF-09 | 5 criteria |
| 9 | Hooks System | Auto-delegate coding tasks via git hooks | HOOK-01 to HOOK-09 | 5 criteria |
| 10 | Enhanced SKILL.md | Smart triggers with model tiering | SKILL-01 to SKILL-08, INT-02 | 5 criteria |
| 11 | Integration & Distribution | Update installer and documentation | INT-01, INT-03 to INT-08 | 4 criteria |

---

## Phase 8: MCP Bridge

**Goal:** Implement MCP server exposing Kimi as callable tools for external AI systems

**Requirements:**
- MCP-01: MCP server implementation
- MCP-02 to MCP-05: Tool implementations (analyze, implement, refactor, verify)
- MCP-06: Transport modes (stdio - HTTP deferred)
- MCP-07: Configuration per tool
- MCP-08: Error handling
- CONF-09: CLI command to start MCP server

**Plans:** 5 plans in 5 waves

**Plan List:**
- [x] 08-01-PLAN.md — MCP Protocol Foundation (JSON-RPC, error codes)
- [x] 08-02-PLAN.md — Configuration Management (config file, env vars)
- [x] 08-03-PLAN.md — Tool Handlers (4 tools, file reading)
- [x] 08-04-PLAN.md — Main Server Executable (message loop, lifecycle)
- [x] 08-05-PLAN.md — CLI Integration (kimi-mcp command, install)

**Status:** ✓ Complete (2026-02-05)
**Verification:** .planning/phases/08-mcp-bridge/08-mcp-bridge-VERIFICATION.md

**Wave Structure:**
| Wave | Plans | Description |
|------|-------|-------------|
| 1 | 08-01 | Core protocol (independent) |
| 2 | 08-02 | Configuration (independent) |
| 3 | 08-03 | Tool handlers (needs 01, 02) |
| 4 | 08-04 | Server executable (needs 01-03) |
| 5 | 08-05 | CLI integration (needs 04) |

**Success Criteria:**
1. MCP server starts and responds to tool calls
2. Each tool (analyze, implement, refactor, verify) works correctly
3. stdio transport functions (HTTP deferred to future)
4. Configuration affects tool behavior as expected
5. Errors return meaningful MCP error codes

**Phase Dependencies:**
- Requires: Configuration system foundation (Phase 7 from v1.0 baseline)
- Provides: MCP tools for external integration

---

## Phase 9: Hooks System

**Goal:** Implement predefined git hooks that auto-delegate hands-on coding tasks to Kimi

**Requirements:**
- HOOK-01: Git pre-commit hook
- HOOK-02: Git post-checkout hook
- HOOK-03: Git pre-push hook
- HOOK-04: File watcher hook (on-save) - *deferred per context*
- HOOK-05: Hook installer (global/local)
- HOOK-06: Hook configuration file
- HOOK-07: Selective hook enablement
- HOOK-08: Hook bypass mechanism
- HOOK-09: Dry-run mode

**Plans:** 4 plans in 4 waves

**Plan List:**
- [x] 09-01-PLAN.md — Configuration System (config file, loading, defaults)
- [x] 09-02-PLAN.md — Hook Scripts (pre-commit, post-checkout, pre-push)
- [x] 09-03-PLAN.md — Installer (global/local install, CLI tools)
- [x] 09-04-PLAN.md — Integration (install.sh, README, verification)

**Status:** ✓ Complete (2026-02-05)
**Verification:** .planning/phases/09-hooks-system/09-hooks-system-VERIFICATION.md

**Wave Structure:**
| Wave | Plans | Description |
|------|-------|-------------|
| 1 | 09-01 | Configuration system (independent) |
| 2 | 09-02 | Hook scripts (needs config) |
| 3 | 09-03 | Installer (needs hook scripts) |
| 4 | 09-04 | Integration (needs installer) |

**Success Criteria:**
1. Hooks install successfully (both global and per-project)
2. Pre-commit hook auto-fixes issues before commit
3. Post-checkout hook analyzes changed files
4. Pre-push hook runs tests and fixes failures
5. Configuration controls hook behavior correctly

**Phase Dependencies:**
- Requires: MCP Bridge (Phase 8) for tool invocation
- Provides: Automated delegation via git workflow

---

## Phase 10: Enhanced SKILL.md

**Goal:** Implement smart triggers for autonomous delegation with intelligent model selection (K2 for routine, K2.5 for creative/UI)

**Requirements:**
- SKILL-01: Model selection logic (K2 vs K2.5)
- SKILL-02: File extension → model mapping
- SKILL-03: Task type → model mapping
- SKILL-04: Code pattern detection triggers
- SKILL-05: Auto-delegation confidence threshold
- SKILL-06: Context preservation across delegations
- SKILL-07: Cost estimation before delegation
- SKILL-08: Override mechanism
- INT-02: Update SKILL.md with v2.0 patterns

**Plans:** 4 plans in 4 waves

**Plan List:**
- [x] 10-01-PLAN.md — Configuration and Classification (model-rules.json, task-classifier.sh)
- [x] 10-02-PLAN.md — Model Selection Engine (kimi-model-selector.sh with confidence scoring)
- [x] 10-03-PLAN.md — Cost Estimation and Wrapper Integration (kimi-cost-estimator.sh, enhanced wrapper)
- [x] 10-04-PLAN.md — Documentation Update (SKILL.md with v2.0 patterns)

**Status:** ✓ Complete (2026-02-05)
**Verification:** .planning/phases/10-enhanced-skill/10-VERIFICATION.md

**Wave Structure:**
| Wave | Plans | Description |
|------|-------|-------------|
| 1 | 10-01 | Configuration and classification (independent) |
| 2 | 10-02 | Model selection engine (needs 10-01) |
| 3 | 10-03 | Cost estimation and integration (needs 10-01, 10-02) |
| 4 | 10-04 | Documentation (needs all above) |

**Success Criteria:**
1. Routine tasks (refactoring, tests) use K2 automatically
2. Creative/UI tasks use K2.5 automatically
3. File extensions correctly map to appropriate models
4. Confidence threshold prevents low-confidence delegations
5. Cost estimates display before delegation

**Phase Dependencies:**
- Requires: Hooks System (Phase 9) for trigger points
- Provides: Intelligent delegation decisions

---

## Phase 11: Integration & Distribution

**Goal:** Update installer, documentation, and Claude Code integration for v2.0

**Requirements:**
- INT-01: Update install.sh for v2.0
- INT-03: Update CLAUDE.md with new slash commands
- INT-04: Create `kimi-mcp.md` slash command
- INT-05: Create `kimi-hooks.md` slash command
- INT-06: MCP setup guide
- INT-07: Hooks configuration guide
- INT-08: Model selection best practices

**Success Criteria:**
1. install.sh installs all v2.0 components
2. New slash commands work in Claude Code
3. Documentation covers MCP setup
4. Documentation covers hooks configuration
5. Model selection guide helps users understand K2 vs K2.5

**Phase Dependencies:**
- Requires: All previous phases complete
- Provides: Complete v2.0 distribution

---

## Requirement Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| MCP-01 to MCP-08 | Phase 8 | Complete |
| CONF-09 | Phase 8 | Complete |
| HOOK-01 to HOOK-09 | Phase 9 | Complete |
| SKILL-01 to SKILL-08 | Phase 10 | Complete |
| INT-02 | Phase 10 | Complete |
| INT-01, INT-03 to INT-08 | Phase 11 | Pending |
| CONF-01 to CONF-08 | Phase 7* | Complete |

*Note: Configuration system foundation (CONF-01 to CONF-08) assumed from v1.0 baseline or completed as part of Phase 8 initialization.

**Coverage:**
- Total v2.0 requirements: 41
- Mapped to phases: 41
- Unmapped: 0 ✓

---

## Execution Order

**Sequential execution recommended:**

1. **Phase 8 (MCP Bridge)** → Foundation for external integration
2. **Phase 9 (Hooks System)** → Builds on MCP for git workflow
3. **Phase 10 (Enhanced SKILL.md)** → Adds intelligence to triggers
4. **Phase 11 (Integration)** → Packages everything for distribution

**Rationale:**
- MCP Bridge is the foundation — hooks and SKILL.md use MCP tools
- Hooks System depends on MCP for actual delegation
- Enhanced SKILL.md depends on hooks for trigger points
- Integration must happen last when all components are stable

---

## Risk Mitigation

| Risk | Mitigation | Phase |
|------|------------|-------|
| MCP protocol complexity | Start with stdio transport, add HTTP later | 8 |
| Git hook performance | Add timeout and async options | 9 |
| Model selection accuracy | Start conservative, tune based on feedback | 10 |
| Configuration conflicts | Clear precedence rules (project > global) | 8-9 |

---

## Definition of Done (v2.0)

v2.0 is complete when:

1. ✓ MCP server exposes Kimi as callable tools
2. ✓ Git hooks auto-delegate coding tasks
3. ✓ SKILL.md intelligently selects K2 vs K2.5
4. ✓ Configuration supports global and per-project setups
5. ✓ Documentation covers all new features
6. ✓ install.sh sets up v2.0 components
7. ✓ All 41 requirements verified

---

*Roadmap created: 2026-02-05*  
*Next step: `/gsd-plan-phase 8` to begin MCP Bridge implementation*
