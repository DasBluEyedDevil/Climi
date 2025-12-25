# VitruvianRedux - Claude Code Project Instructions

## Core Principles

1. **Use Skills** - Most detailed information is in `.skills/` files. Invoke them.
2. **Use Quadrumvirate Delegation** - Conserve tokens by delegating to subagents
3. **Use Daem0nMCP** - Your long-term memory system for context persistence

---

## Quick Start: Session Protocol

<EXECUTE_IMMEDIATELY>
At session start, DO NOT WAIT for user input. Execute this automatically:

1. **Check for `mcp__daem0nmcp__get_briefing` tool**
   - IF MISSING: Run installation commands from `daem0nmcp-integration` skill, then inform user to restart
   - IF PRESENT: Call `mcp__daem0nmcp__get_briefing()` NOW

2. **Report to user**: "Daem0nMCP ready. [X] memories. [Y] warnings."

3. **If warnings/failed approaches exist**: Mention them proactively
</EXECUTE_IMMEDIATELY>

---

## Project Overview

**Vitruvian Redux** is an Android app for controlling Vitruvian Trainer workout machines via Bluetooth Low Energy (BLE). Community rescue project after company bankruptcy.

| Property | Value |
|----------|-------|
| Status | Beta 1 - Core functionality complete |
| Version | 0.1.0-alpha |
| Min API | 26 (Android 8.0) |
| Target API | 36 |
| Language | Kotlin 1.9+ |
| UI | Jetpack Compose |
| Architecture | Clean Architecture + MVVM |
| DI | Hilt/Dagger |
| BLE | Nordic BLE Library |
| Database | Room |

---

## Skills Reference

### Infrastructure Skills
| Skill | When to Use |
|-------|-------------|
| `quadrumvirate-orchestration` | Delegating work to Gemini/Codex/Copilot |

### Agent Role Skills
| Skill | When to Use |
|-------|-------------|
| `Claude-Orchestrator` | Understanding your orchestration role |
| `Gemini-Researcher` | Delegating code analysis to Gemini |
| `Copilot-Engineer` | Delegating backend/BLE work to Copilot |

---

## Wrapper Scripts

All CLI tools have wrapper scripts in `.skills/`:
```bash
.skills/gemini.agent.wrapper.sh -d "@app/src/" "[query]"  # Code analysis
.skills/codex.agent.wrapper.sh "[task]"                    # UI/Visual work
.skills/copilot.agent.wrapper.sh --allow-write "[task]"    # Backend/BLE
```

---

## Session End Protocol

**MANDATORY at end of every session:**

1. Update `CHANGELOG.md` with changes made
2. Update `LAST_SESSION.md` with current state
3. Document incomplete work or next steps
4. Run tests if significant changes made
5. Commit if requested

---

## Memory Files

- **CHANGELOG.md**: Comprehensive change history (append-only)
- **LAST_SESSION.md**: Current state snapshot (overwrite each session)

---

## When in Doubt

1. **Invoke a skill** - Most information is in `.skills/` files
2. **Ask Gemini** - Use 1M context for code analysis
3. **Delegate** - Let Codex/Copilot implement

