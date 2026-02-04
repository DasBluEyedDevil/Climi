# Feature Research: Claude Code + Kimi CLI Integration Plugin

**Domain:** AI CLI wrapper plugin for multi-model coding workflows
**Researched:** 2026-02-04
**Confidence:** MEDIUM-HIGH

## Context: What Kimi CLI Handles Natively

Before categorizing wrapper features, it is critical to understand what Kimi CLI provides out of the box. The wrapper should NOT re-implement what Kimi already does well.

### Kimi CLI Native Capabilities (HIGH confidence -- verified via official docs)

| Capability | Kimi Native Flag/Feature | Wrapper Needed? |
|------------|--------------------------|-----------------|
| Agent/role system | `--agent-file path.yaml` with YAML configs, inheritance via `extend`, subagents | NO -- use native agent files |
| Thinking mode | `--thinking` / `--no-thinking` flags | NO -- pass-through only |
| Model selection | `--model NAME` from config.toml | NO -- pass-through only |
| MCP server support | `--mcp-config-file`, `--mcp-config`, `kimi mcp` subcommands | NO -- native |
| Non-interactive scripting | `--print` mode with `--output-format text\|stream-json` | NO -- this IS the integration point |
| Auto-approval | `--yolo` / `--yes` flags | NO -- pass-through only |
| Session management | `--session ID`, `--continue` | NO -- native |
| Skills system | `--skills-dir`, SKILL.md files with auto-discovery | NO -- native |
| Context auto-compaction | Built-in context compression when approaching limits | NO -- native |
| Retry/loop control | `--max-steps-per-turn`, `--max-retries-per-step` | NO -- native |
| System prompt variables | `${KIMI_NOW}`, `${KIMI_WORK_DIR}`, `${KIMI_WORK_DIR_LS}`, `${KIMI_AGENTS_MD}`, `${KIMI_SKILLS}` | NO -- native |
| Web search/fetch | Built-in web tools | NO -- native |
| File read/write | Built-in file tools | NO -- native |
| Shell execution | Built-in shell tool | NO -- native |
| Quiet/final-only output | `--quiet`, `--final-message-only` | NO -- pass-through only |

### What the Wrapper Must Provide (Kimi Cannot Do These)

| Capability | Why Kimi Cannot Do This | Wrapper Responsibility |
|------------|------------------------|----------------------|
| Claude Code integration | Kimi has no awareness of Claude Code's plugin system | Wrapper bridges the two systems |
| Slash commands | Claude Code feature, not a Kimi feature | Wrapper provides `/kimi-*` commands |
| Git diff injection | Kimi reads files but does not auto-inject diffs into prompts | Wrapper captures and injects diff |
| Context file injection | Project context (KIMI.md) loaded and prepended to prompts | Wrapper loads and injects |
| Agent file management | Kimi loads one `--agent-file` at a time; no role-switching UX | Wrapper provides `-r role` shortcut |
| Output formatting for Claude | Kimi output needs structuring for Claude consumption | Wrapper appends format instructions |
| Cross-platform shim | Kimi CLI is Python-based; Claude Code runs on various OS | Wrapper handles Windows/PowerShell |

---

## Feature Landscape

### Table Stakes (Users Expect These)

Features users assume exist. Missing these = product feels broken or pointless.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| **Slash commands** (analyze, verify, trace, audit) | Core UX -- how users invoke Kimi from Claude Code | LOW | Markdown files in `commands/` dir. Direct mapping from existing Gemini commands. |
| **Role switching** (`-r reviewer`, `-r planner`, etc.) | Users expect persona-based prompting without YAML knowledge | LOW | Thin layer: maps `-r name` to `--agent-file .kimi/agents/name.yaml`. Kimi does the heavy lifting. |
| **Agent file library** (5-8 predefined agents) | Users need working roles out-of-the-box; empty agent dir is useless | MEDIUM | Ship: reviewer, planner, debugger, explainer, security, auditor, documenter, onboarder. YAML format with `extend: default`. |
| **Diff injection** (`--diff`) | Verification workflow requires seeing what changed | LOW | `git diff` capture, injected as prompt prefix or via stdin piping. Already proven in Gemini wrapper. |
| **Context file loading** (KIMI.md / .kimi/context.md) | Users expect project-specific instructions to be auto-loaded | LOW | Check project root and .kimi/ dir for context file, prepend to prompt. |
| **Non-interactive print mode** | Claude Code needs programmatic output, not interactive REPL | LOW | Always pass `--print --output-format text --final-message-only`. This is how the wrapper talks to Kimi. |
| **Cross-platform support** (Bash + PowerShell shim) | Windows users exist; Claude Code runs on Windows | LOW | PowerShell `.ps1` shim that resolves bash path and delegates. Proven pattern from Gemini wrapper. |
| **Install/uninstall script** | Published plugin quality requires clean setup | LOW | Copy files to `~/.claude/`, set up `.kimi/` agent directory structure. |
| **Error handling and user feedback** | Silent failures are unacceptable in a published tool | LOW | Check `kimi` binary exists, validate role names, report errors clearly to stderr. |
| **Structured output format** | Claude needs parseable, consistent output from Kimi | LOW | Append format instructions (SUMMARY/FILES/ANALYSIS/RECOMMENDATIONS) to all prompts via agent system prompts. |

### Differentiators (Competitive Advantage Over Raw Kimi CLI)

Features that make the plugin more valuable than just running `kimi --print -p "query"` manually.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| **Template system** (feature, bug, verify, architecture, implement-ready, fix-ready) | Pre-structured prompts that elicit better analysis than ad-hoc queries | LOW | 6 template files in `.kimi/templates/`. Pure markdown, loaded and prepended. Zero runtime complexity. |
| **Thinking mode toggle** | Let users request deep reasoning vs. fast responses per-query | LOW | Pass `--thinking` or `--no-thinking` to Kimi. Expose as `--think` flag in wrapper. No wrapper logic needed. |
| **Agent inheritance architecture** | Users create custom agents that extend shipped defaults without copy-pasting | LOW | Kimi's native `extend:` handles this. Wrapper just documents the pattern and ships base agents that are designed to be extended. |
| **CLAUDE.md workflow instructions** | Auto-inject delegation rules so Claude knows WHEN to invoke Kimi | LOW | Part of install: write delegation rules into CLAUDE.md. Not a runtime feature. |
| **Dry-run mode** (`--dry-run`) | Debug prompt construction without API calls; see exactly what Kimi receives | LOW | Build prompt, print to stdout, exit. No Kimi invocation. Proven useful in Gemini wrapper. |
| **Diff-aware context** (`--diff-aware`) | Only analyze files changed in current branch, not entire codebase | MEDIUM | `git diff --name-only main...HEAD` to get changed files, pass as targeted context. Saves tokens on large repos. |
| **Custom template directory** | Power users create project-specific templates beyond the 6 shipped | LOW | Check `.kimi/templates/` for user templates before falling back to built-in. Already proven pattern. |
| **Verbose/quiet toggle** | Quiet by default for Claude consumption; verbose for human debugging | LOW | `--verbose` flag shows spinner, status messages to stderr. Default: quiet, output only Kimi response. |
| **Plugin-native distribution** | Install via `/plugin install` from a marketplace or GitHub repo | MEDIUM | Package as a proper Claude Code plugin with `.claude-plugin/plugin.json`, `commands/`, `agents/`, `skills/`. Modern distribution. |

### Anti-Features (Deliberately NOT Building)

Features that seem appealing but add complexity without proportional value. Many were in the Gemini wrapper and should NOT be carried forward.

| Anti-Feature | Why Requested | Why Problematic | What to Do Instead |
|--------------|---------------|-----------------|-------------------|
| **Response caching** (`--cache`, `--cache-ttl`, `--clear-cache`) | "Save API costs on repeated queries" | Stale caches cause incorrect analysis. Cache invalidation is hard. Kimi's context is dynamic (code changes between queries). Added 40+ lines to Gemini wrapper for marginal benefit. | Let users re-run queries. Kimi is fast and cheap. If users want caching, they can pipe output to a file themselves. |
| **Chat history / session management** (`--chat SESSION`) | "Continue conversations across invocations" | The wrapper is invoked per-query by Claude Code. Multi-turn conversations belong in Kimi's native interactive mode, not in a non-interactive wrapper. Added JSON history file management, jq dependency, 40+ lines. | Use Kimi's native `--session` and `--continue` flags if multi-turn is needed. The wrapper's job is single-shot queries. |
| **Batch mode** (`--batch FILE`) | "Process multiple queries at once" | Over-engineering. Claude Code invokes one query at a time. If you need batch, write a shell loop. The recursive self-invocation pattern in the Gemini wrapper was fragile. | Users can write `for q in queries; do wrapper.sh "$q"; done`. Unix philosophy. |
| **Token estimation** (`--estimate`) | "Know the cost before running" | Inaccurate (Gemini wrapper used chars/4 heuristic). Kimi models have different tokenizers. Creates false confidence about costs. | Remove entirely. Users who care about cost can check Kimi's billing dashboard. |
| **Smart context search** (`--smart-ctx KEYWORDS`) | "Auto-find relevant files by keyword" | Grep-based file discovery is crude. Kimi already has file read tools and can search the codebase itself natively. The wrapper grep duplicates Kimi's capability poorly. | Let Kimi find relevant files. It has built-in file and search tools. Pass directory hints with `-d` if needed. |
| **Structured output schemas** (`--schema files\|issues\|plan\|json`) | "Get machine-parseable JSON output" | Complex prompt engineering for brittle JSON output. LLMs produce inconsistent JSON. The wrapper's structured output format (SUMMARY/FILES/ANALYSIS/RECOMMENDATIONS) is sufficient for Claude consumption. | Keep the standard text format with section headers. Claude can parse markdown sections. |
| **Retry/fallback logic** (primary model -> fallback model) | "Handle API failures gracefully" | Kimi CLI has native `--max-retries-per-step`. Adding wrapper-level retry with exponential backoff AND model fallback (as Gemini wrapper did) duplicates native capability and adds 60+ lines. | Rely on Kimi's native retry. If Kimi fails, the wrapper reports the error. No model fallback -- users pick their model. |
| **Response validation** (`--validate`) | "Ensure response matches expected format" | Extra dependency (parser script). LLM responses are inherently variable. Validation that rejects valid-but-differently-formatted responses causes more problems than it solves. | Trust the agent's system prompt to produce consistent format. If format drifts, fix the system prompt. |
| **Save last response** (`--save-response`) | "Parse response later" | File I/O for a feature that shell redirection (`> output.txt`) already provides. | Users pipe output: `wrapper.sh "query" > analysis.txt`. Unix philosophy. |
| **Context change detection** (`--context-check`) | "Warn if files changed since last query" | Hash computation over directories is slow. Stale context is a caching problem -- and we are not caching. | Not applicable without caching. Every query gets fresh context. |
| **Summarize mode** (`--summarize`) | "Get shorter responses" | Appending "be concise" to prompts is something users can do themselves. One flag that appends one sentence is not worth maintaining. | Users add "be concise" to their query if needed. Or create a "concise" agent variant. |
| **Color output / progress spinners** | "Pretty terminal output" | The wrapper output is consumed by Claude Code, not humans. ANSI colors in Claude's context window are noise. Spinners require background processes. | No ANSI colors in output. Minimal stderr messages only when `--verbose` is set. |
| **jq dependency** | "Parse JSON chat history" | External dependency that may not be installed. Chat history is an anti-feature anyway. | No JSON processing needed. Text output only. |
| **Log file** (`--log FILE`) | "Debug wrapper execution" | Adds file I/O for a developer-only feature. `--dry-run` and `--verbose` provide sufficient debugging. | Use `--dry-run` to see constructed prompt. Use `--verbose` for status messages. |

---

## Feature Dependencies

```
[Slash Commands]
    |-- requires --> [Wrapper Script (core)]
    |                    |-- requires --> [Kimi CLI installed]
    |                    |-- requires --> [Print mode invocation]
    |                    |-- requires --> [Error handling]
    |                    |
    |                    |-- enhances --> [Role switching (-r)]
    |                    |                    |-- requires --> [Agent file library]
    |                    |
    |                    |-- enhances --> [Template system (-t)]
    |                    |
    |                    |-- enhances --> [Diff injection (--diff)]
    |                    |
    |                    |-- enhances --> [Context file loading]
    |                    |
    |                    |-- enhances --> [Thinking mode toggle]
    |
    |-- requires --> [Cross-platform shim (PowerShell)]

[Plugin distribution]
    |-- requires --> [plugin.json manifest]
    |-- requires --> [All above features working]

[CLAUDE.md workflow instructions]
    |-- independent, install-time only
```

### Dependency Notes

- **Slash commands require wrapper script**: Commands are thin markdown files that tell Claude how to invoke the wrapper. The wrapper does the real work.
- **Role switching requires agent file library**: The `-r reviewer` shortcut only works if `.kimi/agents/reviewer.yaml` exists. Ship them together.
- **Plugin distribution requires everything else**: Package as plugin only after all core features are stable.
- **CLAUDE.md is independent**: Can be written at install time. No runtime dependency.

---

## Gemini Wrapper Feature Audit: Keep vs. Drop

Explicit mapping of every Gemini wrapper feature to its Kimi equivalent.

| Gemini Wrapper Feature | Lines of Code | Kimi Native? | Decision | Rationale |
|------------------------|---------------|--------------|----------|-----------|
| Role system (15 .md files) | ~60 (loader) | YES (`--agent-file` with YAML) | **KEEP but simplify** -- roles become agent YAML files, wrapper maps `-r name` to `--agent-file` | Kimi agents are more powerful than Gemini roles (inheritance, tools, subagents) |
| Templates (6 built-in) | ~90 (case statement) | No native equivalent | **KEEP** -- load template .md files, prepend to prompt | Templates structure the query, not the agent persona. Complementary to agents. |
| Context file injection | ~20 | Partial (Kimi has `${KIMI_WORK_DIR}` vars but no project context file loading) | **KEEP** -- load KIMI.md, prepend to prompt | Project-specific instructions need explicit injection |
| Diff injection | ~25 | NO | **KEEP** -- `git diff` capture + prepend | Core verification workflow feature |
| PowerShell shim | 45 | NO | **KEEP** -- proven pattern, minimal | Windows support |
| Install/uninstall | ~50 each | NO | **KEEP** -- adapt for Kimi structure | Distribution requirement |
| Caching | ~45 | NO (not needed) | **DROP** | Complexity without value in single-shot queries |
| Chat history | ~40 | YES (`--session`, `--continue`) | **DROP** | Kimi handles this natively |
| Batch mode | ~35 | NO (not needed) | **DROP** | Shell loops serve this need |
| Token estimation | ~15 | NO | **DROP** | Inaccurate heuristic |
| Smart context search | ~25 | YES (Kimi has file search tools) | **DROP** | Kimi does this better natively |
| Structured output schemas | ~50 | NO | **DROP** | Standard format sections are sufficient |
| Retry with fallback | ~65 | YES (`--max-retries-per-step`) | **DROP** | Native retry is sufficient |
| Response validation | ~15 | NO | **DROP** | Brittle and unnecessary |
| Save last response | ~10 | NO | **DROP** | Shell redirection suffices |
| Context change detection | ~20 | NO | **DROP** | Not useful without caching |
| Summarize mode | ~8 | NO | **DROP** | User can add "be concise" to query |
| Verbose mode / spinners | ~30 | NO | **SIMPLIFY** -- minimal stderr messages only | No spinners, no colors in output |
| Dry-run mode | ~10 | NO | **KEEP** -- useful debugging | Show constructed prompt without API call |
| Logging | ~10 | YES (`--debug` flag) | **DROP** | Kimi has native debug logging |
| Prompt size validation | ~8 | YES (native context limits) | **DROP** | Kimi handles context overflow natively |

**Result: ~1060 lines of Gemini wrapper reduces to ~200-300 lines of Kimi wrapper.**

---

## MVP Definition

### Launch With (v1)

Minimum viable product -- what is needed to validate the Eyes/Hands workflow with Kimi.

- [ ] **Core wrapper script** (Bash) -- argument parsing, prompt construction, Kimi invocation via `--print` mode
- [ ] **4 slash commands** -- `/kimi-analyze`, `/kimi-verify`, `/kimi-trace`, `/kimi-audit`
- [ ] **5-8 agent files** (YAML) -- reviewer, planner, debugger, explainer, security, auditor, documenter, onboarder
- [ ] **6 templates** -- feature, bug, verify, architecture, implement-ready, fix-ready
- [ ] **Context file loading** -- Auto-load KIMI.md from project root or .kimi/ directory
- [ ] **Diff injection** -- `--diff [TARGET]` flag that captures and injects git diff
- [ ] **PowerShell shim** -- Windows compatibility
- [ ] **Role switching** -- `-r name` maps to `--agent-file .kimi/agents/name.yaml`
- [ ] **Error handling** -- Check kimi binary, validate roles, report errors to stderr
- [ ] **CLAUDE.md integration** -- Delegation rules instructing Claude when/how to invoke Kimi

### Add After Validation (v1.x)

Features to add once core workflow is proven.

- [ ] **Plugin-native packaging** -- `.claude-plugin/plugin.json` with proper manifest for `/plugin install` distribution
- [ ] **Dry-run mode** -- `--dry-run` to show constructed prompt without API call
- [ ] **Thinking mode toggle** -- `--think` flag passed through to Kimi's `--thinking`
- [ ] **Diff-aware context** -- `--diff-aware` flag to scope analysis to changed files only
- [ ] **Custom template directory** -- Load from `.kimi/templates/` alongside built-ins
- [ ] **Verbose mode** -- `--verbose` for human debugging

### Future Consideration (v2+)

Features to defer until the ecosystem matures and user demand is clear.

- [ ] **Hooks integration** -- PostToolUse hooks to auto-verify after Claude edits files
- [ ] **MCP bridge** -- Expose Kimi's analysis as an MCP tool Claude can invoke directly
- [ ] **Agent marketplace** -- Share community agent files for specific frameworks/languages
- [ ] **LSP integration** -- Feed Kimi's analysis through Claude Code's LSP plugin system

---

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| Core wrapper script | HIGH | MEDIUM | P1 |
| Slash commands (4) | HIGH | LOW | P1 |
| Agent file library (5-8) | HIGH | MEDIUM | P1 |
| Context file loading | HIGH | LOW | P1 |
| Diff injection | HIGH | LOW | P1 |
| Role switching (`-r`) | HIGH | LOW | P1 |
| Error handling | HIGH | LOW | P1 |
| Templates (6) | MEDIUM | LOW | P1 |
| PowerShell shim | MEDIUM | LOW | P1 |
| CLAUDE.md integration | MEDIUM | LOW | P1 |
| Structured output format | MEDIUM | LOW | P1 |
| Plugin packaging | MEDIUM | MEDIUM | P2 |
| Dry-run mode | LOW | LOW | P2 |
| Thinking mode toggle | MEDIUM | LOW | P2 |
| Diff-aware context | MEDIUM | MEDIUM | P2 |
| Custom template dir | LOW | LOW | P2 |
| Verbose mode | LOW | LOW | P2 |
| Hooks integration | MEDIUM | HIGH | P3 |
| MCP bridge | HIGH | HIGH | P3 |
| Agent marketplace | LOW | HIGH | P3 |

**Priority key:**
- P1: Must have for launch
- P2: Should have, add when possible
- P3: Nice to have, future consideration

---

## Competitor Feature Analysis

| Feature | Gemini Wrapper (existing) | Raw Kimi CLI | Aider | Our Approach |
|---------|--------------------------|-------------|-------|--------------|
| Role/persona system | 15 roles as .md files, loaded inline | Agent YAML with inheritance, tools, subagents | No explicit roles | YAML agent files using Kimi's native system. Ship 5-8, designed for extension via `extend:`. |
| Templates | 6 hardcoded case statements | None | None | 6 template .md files, loadable from project dir. External files, not hardcoded. |
| Diff injection | Inline in wrapper, git diff capture | Not built-in | Native git awareness | Wrapper captures diff, injects as prompt context. Same proven pattern. |
| Multi-model fallback | Primary + fallback model with retry | Single model per config, native retry | Multi-model via config | Single model. No fallback. Users configure their preferred model in Kimi's config.toml. |
| Context management | Manual directory injection (`-d @src/`) | Native file tools, auto-compaction | Repo map, auto-context | Kimi handles context natively. Wrapper adds project context file (KIMI.md) only. |
| Caching | MD5-based response cache with TTL | None | None | None. Deliberately omitted. |
| Chat/session | JSON history files, jq-based | Native `--session` + `--continue` | Native conversation mode | Defer to Kimi native. Wrapper is single-shot. |
| IDE integration | Claude Code slash commands | VS Code extension, ACP protocol | Editor plugins | Claude Code slash commands + plugin manifest. |
| Thinking mode | Not applicable (Gemini has no equivalent) | Native `--thinking` flag | Not applicable | Pass-through flag. Let Kimi handle it. |
| MCP support | Not applicable | Native MCP client + server management | Not applicable | Kimi handles MCP natively. No wrapper involvement. |
| Output structure | ROLE_OUTPUT_FORMAT appended to all prompts | No standard format | Structured diff output | Append format instructions via agent system prompts (SUMMARY/FILES/ANALYSIS/RECOMMENDATIONS). |
| Plugin distribution | Manual file copy via install.sh | N/A | pip install | Claude Code plugin system (`.claude-plugin/plugin.json`). Modern, installable. |

---

## Key Design Principles

Based on research, these principles should guide feature decisions:

1. **Wrapper = Bridge, Not Runtime.** The wrapper's job is to connect Claude Code to Kimi CLI. It translates Claude's requests into Kimi commands and structures the output. It does NOT manage state, cache responses, or maintain sessions.

2. **Delegate to Kimi.** If Kimi can do it natively (retry, context management, MCP, sessions, thinking mode), let Kimi do it. Pass flags through; do not re-implement.

3. **Unix Philosophy.** Each component does one thing well. The wrapper constructs prompts and invokes Kimi. Templates structure queries. Agent files define personas. Slash commands provide the UX.

4. **External Configuration.** Agents are YAML files, not hardcoded case statements. Templates are .md files, not inline strings. Users can add/modify without touching the wrapper script.

5. **Quiet by Default.** Output goes to Claude, not humans. No ANSI colors, no spinners, no progress bars in the output stream. Stderr for errors only. Verbose mode opt-in.

6. **Minimal Dependencies.** Bash + git + kimi CLI. No jq, no bc, no md5sum. PowerShell shim for Windows, but the core is pure Bash.

---

## Sources

### HIGH Confidence (Official Documentation)
- [Kimi CLI GitHub Repository](https://github.com/MoonshotAI/kimi-cli) -- features, installation
- [Kimi CLI Agents and Subagents](https://moonshotai.github.io/kimi-cli/en/customization/agents.html) -- agent YAML format, inheritance
- [Kimi CLI Skills](https://moonshotai.github.io/kimi-cli/en/customization/skills.html) -- skills system
- [Kimi CLI Config Files](https://moonshotai.github.io/kimi-cli/en/configuration/config-files.html) -- config.toml format
- [Kimi CLI Command Reference](https://www.kimi-cli.com/en/reference/kimi-command.html) -- complete CLI flags
- [Claude Code Plugins Reference](https://code.claude.com/docs/en/plugins-reference) -- plugin structure, manifest
- [Claude Code Slash Commands](https://code.claude.com/docs/en/slash-commands) -- command format

### MEDIUM Confidence (Verified Multiple Sources)
- [Kimi CLI Technical Deep Dive](https://llmmultiagents.com/en/blogs/kimi-cli-technical-deep-dive) -- architecture details
- [DeepWiki CLI Options Reference](https://deepwiki.com/MoonshotAI/kimi-cli/2.3-command-line-options-reference) -- comprehensive flag list
- [Awesome Claude Code Plugins](https://github.com/ccplugins/awesome-claude-code-plugins) -- plugin ecosystem patterns
- [Claude Code Plugin Lessons](https://pierce-lamb.medium.com/what-i-learned-while-building-a-trilogy-of-claude-code-plugins-72121823172b) -- plugin best practices
- [Unix/BASH Agent Philosophy](https://thenewstack.io/the-key-to-agentic-success-let-unix-bash-lead-the-way/) -- minimal design validation

### LOW Confidence (Single Source / Unverified)
- [Kimi K2.5 with Claude Code](https://medium.com/@joe.njenga/i-tested-kimi-k2-5-with-claude-code-1-trillion-parameters-8x-cheaper-than-opus-8d4f9e9c7b4d) -- integration examples
- [Multi-Model Claude Code](https://rakesh.tembhurne.com/blog/ai-tools/extend-claude-code-multiple-models-complete-guide) -- multi-model patterns

---
*Feature research for: Claude Code + Kimi CLI Integration Plugin*
*Researched: 2026-02-04*
