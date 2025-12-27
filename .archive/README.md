# Archived Engineering Subagents

This directory contains the archived Codex and Copilot engineering subagent documentation and wrappers that were removed when the repository was refocused on **Gemini as a Large-Context Companion for Claude Code**.

## Why These Were Removed

The original Multi-Agent Workflow treated Gemini, Codex, and Copilot as equal "engineering subagents" with Claude as orchestrator. The repository has been refocused to leverage Gemini's unique strength: its massive 1M+ token context window for code analysis and research.

## Accessing the Multi-Agent Version

If you need the full multi-agent workflow system, check out the last commit before this refactoring:

```bash
git log --all --oneline | grep -i "refactor\|gemini-focused\|remove.*subagent"
```

Or browse the git history to find the commit just before the removal.

## Files Archived

- `Codex-Engineer.md` - UI/frontend engineering subagent documentation
- `codex.agent.wrapper.sh` - Codex CLI wrapper script
- `Copilot-Engineer.md` - Backend/BLE engineering subagent documentation
- `copilot.agent.wrapper.sh` - Copilot CLI wrapper script

## Current Focus

The repository now focuses exclusively on using Gemini for code analysis and research to complement Claude Code's development workflow. See the main README.md for the updated approach.
