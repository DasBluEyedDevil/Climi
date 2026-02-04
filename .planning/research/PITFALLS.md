# Pitfalls Research

**Domain:** CLI wrapper plugin (Kimi CLI integration for Claude Code)
**Researched:** 2026-02-04
**Confidence:** MEDIUM-HIGH (Kimi CLI pitfalls verified from GitHub issues; cross-platform pitfalls from multiple sources; Claude Code plugin pitfalls from official docs and issue tracker)

## Critical Pitfalls

### Pitfall 1: Kimi CLI Version Instability and Breaking Changes

**What goes wrong:**
Kimi CLI has demonstrated severe regressions between minor versions. The v0.75-to-v0.78 transition replaced the internal "Ralph Loop" with a "Prompt Flow" system, causing context to fill to 100% instantly and agents to enter infinite loops. Users described the tool as going from "miraculous" to "total garbage" in two iterations. The wrapper may call a Kimi CLI version that behaves completely differently from the one tested against.

**Why it happens:**
Kimi CLI is under rapid active development (847+ GitHub issues as of Feb 2026). Architectural changes like the Ralph Loop to Prompt Flow migration happen between minor versions without clear deprecation warnings. The `uv tool install kimi-cli` command installs the latest version by default, meaning any user running `install.sh` could get a different Kimi CLI version than the one the wrapper was tested with.

**How to avoid:**
- Document the minimum and maximum tested Kimi CLI versions in README and in the install script.
- Add a version check at wrapper startup: `kimi --version` parsed and compared against a known-good range.
- Pin the Kimi CLI version in install instructions: `uv tool install kimi-cli==X.Y.Z` rather than just `uv tool install kimi-cli`.
- Test the wrapper against at least two Kimi CLI versions before each release.
- Use `--quiet` mode exclusively for non-interactive use (this is the most stable interface for programmatic consumption).

**Warning signs:**
- Kimi CLI output format changes (extra lines, different JSON structure).
- New error messages appearing in stderr that were not there before.
- `--quiet` mode producing non-text output or extra metadata.
- Users reporting "it worked yesterday, now it does not."

**Phase to address:**
Phase 1 (Core wrapper) -- version check should be one of the first things implemented.

**Confidence:** HIGH -- verified from [GitHub issue #643](https://github.com/MoonshotAI/kimi-cli/issues/643) and [issue #748](https://github.com/MoonshotAI/kimi-cli/issues/748).

---

### Pitfall 2: Windows PATH and "CLI Not Found" After System Updates

**What goes wrong:**
After Windows updates (specifically KB5078127 in Jan 2026), the `kimi` command becomes unfindable. The PATH entry for `~/.local/bin` (where `uv tool install` places binaries) gets lost or the executable loses its association. The PowerShell shim calls `bash` which calls `kimi`, creating a chain of three PATH lookups, any of which can fail.

**Why it happens:**
Windows updates can reset or modify PATH environment variables. The `uv` tool installs `kimi` to `~/.local/bin` which is not a standard Windows PATH location. Git Bash, PowerShell, and cmd.exe each have different PATH resolution behaviors. The current Gemini wrapper's PowerShell shim resolves `bash.exe` across 6 candidate paths, but does not do the same for the wrapped CLI tool itself.

**How to avoid:**
- In the wrapper, do not just check `command -v kimi`. Also check common installation locations explicitly: `~/.local/bin/kimi`, `$(python -m site --user-base)/bin/kimi`, and the `uv` tool directory.
- In the PowerShell shim, resolve the `kimi` binary path before delegating to bash. If not found in PATH, check `$env:USERPROFILE\.local\bin\kimi.exe` and `$env:LOCALAPPDATA\Programs\Python\*\Scripts\kimi.exe`.
- Provide a `KIMI_PATH` environment variable override so users can set the absolute path once and not depend on PATH.
- Print actionable error messages: not just "kimi not found" but "kimi not found in PATH. If installed via uv, ensure ~/.local/bin is in your PATH. You can also set KIMI_PATH=/absolute/path/to/kimi."

**Warning signs:**
- Works on the developer's machine but fails on user's machine.
- Works in Git Bash but not PowerShell (or vice versa).
- Works until a Windows update, then fails.
- `which kimi` returns nothing even though `kimi --version` works from a different terminal.

**Phase to address:**
Phase 1 (Core wrapper) and Phase 4 (Install script) -- binary discovery should be robust from day one, and the installer should validate and persist the path.

**Confidence:** HIGH -- verified from [GitHub issue #800](https://github.com/MoonshotAI/kimi-cli/issues/800) and [Kimi CLI troubleshooting docs](https://deepwiki.com/MoonshotAI/kimi-cli/12-troubleshooting).

---

### Pitfall 3: Over-Engineering the Wrapper (Scope Creep to 1060 Lines Again)

**What goes wrong:**
The previous Gemini wrapper grew to 1060 lines because features kept getting added: caching, chat history, batch mode, smart context grep, token estimation, structured output schemas, retry/fallback logic, spinner animations, context hashing, response validation. Each feature seemed reasonable in isolation but collectively made the script unmaintainable. The Kimi wrapper will face the same pressure -- "just add --thinking support," "just add session resume," "just add subagent delegation."

**Why it happens:**
Shell scripts are easy to prototype with and invite incremental additions. Each new flag feels like "just 20 more lines." But shell scripts lack the testability, modularity, and type safety to handle complexity well. Features that Kimi CLI handles natively (sessions, thinking mode, model selection) get re-implemented in the wrapper because "our interface is simpler." The PROJECT.md already identifies many features as out-of-scope, but scope discipline is hard to maintain under user pressure.

**How to avoid:**
- Enforce a hard line count budget: the wrapper script MUST stay under 300 lines. If it grows beyond that, something is wrong.
- Before adding ANY feature to the wrapper, ask: "Does Kimi CLI already handle this natively?" If yes, do not wrap it. Pass the flag through.
- Maintain an explicit OUT_OF_SCOPE.md list (already started in PROJECT.md). When someone requests a feature, add it to out-of-scope with rationale before considering implementation.
- If the wrapper reaches 500 lines, stop and rewrite as a thin passthrough. The blog post "Avoid Load-bearing Shell Scripts" specifically warns: bail early on the shell script and eat the cost of a simple rewrite before complexity becomes entrenched.
- Template system and role system should be the ONLY complex features. Everything else should be flag-passthrough to `kimi`.

**Warning signs:**
- Adding a feature that requires more than 30 lines of bash.
- Adding a feature that requires a new external dependency (jq, bc, md5sum).
- Implementing retry logic, caching, or session management in the wrapper.
- The wrapper has more command-line flags than Kimi CLI itself.
- Someone says "let me just add a quick..."

**Phase to address:**
All phases -- this is a continuous discipline, not a one-time fix. But Phase 1 (Core wrapper) sets the tone. If the initial implementation is lean, additions will feel out of place. If it starts complex, it will only grow.

**Confidence:** HIGH -- directly observed in the existing codebase at `C:\Users\dasbl\Multi-Agent-Workflow\skills\gemini.agent.wrapper.sh` and corroborated by [Avoid Load-bearing Shell Scripts](https://benjamincongdon.me/blog/2023/10/29/Avoid-Load-bearing-Shell-Scripts/).

---

### Pitfall 4: Agent File Path Resolution Surprises

**What goes wrong:**
Kimi's `system_prompt_path` in agent YAML files is resolved relative to the agent file's location, NOT relative to the working directory. If the wrapper installs agent files to `~/.claude/agents/` but references system prompts at `./prompts/reviewer.md`, the path resolves to `~/.claude/agents/prompts/reviewer.md`, not `./prompts/reviewer.md` from the user's project. Moving agent files to a different directory breaks all prompt references. Symlinks may further confuse resolution.

**Why it happens:**
Different tools resolve relative paths differently. Many developers assume paths are relative to CWD. Kimi chose to resolve relative to the YAML file location (which is actually a reasonable design, but surprising if not expected). The install script copies files to different locations depending on global vs. project installation mode, meaning the same agent YAML might work in one mode and break in another.

**How to avoid:**
- Keep agent YAML files and their system prompt markdown files in the same directory or a consistent relative structure. The recommended layout: `agents/reviewer.yaml` with `agents/prompts/reviewer.md`, where the YAML references `system_prompt_path: ./prompts/reviewer.md`.
- Test agent files from BOTH global (`~/.claude/agents/`) and project-local (`./.kimi/agents/`) installation paths.
- In the install script, verify that the `system_prompt_path` reference is valid after copying by doing a basic existence check.
- Document this behavior prominently: "system_prompt_path is relative to the YAML file, not to your project."
- Consider using `system_prompt` (inline) for simple roles instead of `system_prompt_path` to avoid path issues entirely -- though this bloats the YAML file.

**Warning signs:**
- Agent works when run from the repo directory but fails after installation.
- Error message about "system prompt file not found" that references an unexpected absolute path.
- Global install works but project install does not (or vice versa).

**Phase to address:**
Phase 2 (Role/Agent system) -- this must be designed correctly from the start since the entire role system depends on it.

**Confidence:** HIGH -- verified from [Kimi CLI agent documentation](https://moonshotai.github.io/kimi-cli/en/customization/agents.html) which explicitly states paths are "relative to agent file."

---

### Pitfall 5: Prompt Injection Through Context Files and Repository Content

**What goes wrong:**
The wrapper loads `KimiContext.md` (or equivalent) and passes it to Kimi CLI as part of the system prompt. If a malicious repository contains a crafted context file, it can inject instructions that cause Kimi to execute unintended commands. This is a second-order injection: the attacker does not control the CLI invocation, but controls content that gets included in the prompt. Cyera Research Labs disclosed exactly this class of vulnerability in Gemini CLI, where repository files could inject shell commands via prompt manipulation.

**Why it happens:**
CLI wrappers that bridge LLMs and system execution treat file content as trusted data. When a developer clones a repository and runs the wrapper, context files from that repository are loaded without validation. Kimi's `--quiet` mode implies `--yolo` (auto-approve all operations), meaning injected instructions could trigger file writes, shell commands, or network requests without user confirmation.

**How to avoid:**
- NEVER use `--quiet` mode for action roles (roles with shell/write access). Only use `--quiet` for read-only analysis roles where Kimi cannot modify the system.
- In the agent YAML for analysis roles, explicitly exclude dangerous tools: `exclude_tools: ["kimi_cli.tools.shell:Shell", "kimi_cli.tools.file:FileWrite"]`.
- Add a `--no-context` flag to the wrapper so users can skip context file loading for untrusted repositories.
- Limit the size of loaded context files (e.g., 50KB max) to prevent context flooding.
- Document the trust model: "Context files are loaded from your repository. Do not run this wrapper on untrusted code without reviewing context files first."
- Consider a warning when context files exist in the repo: "Loading KimiContext.md from repository. Review content? [y/N]" (only in interactive mode, not when Claude Code calls it).

**Warning signs:**
- Context files in repositories you did not author.
- Unusually large context files (>10KB for what should be a simple project description).
- Context files containing instructions like "ignore previous instructions" or "execute the following."
- Kimi performing unexpected actions during "analysis" tasks.

**Phase to address:**
Phase 2 (Role/Agent system) for tool restriction in agent files, and Phase 1 (Core wrapper) for context file loading safety.

**Confidence:** HIGH -- verified from [Cyera Research Labs disclosure on Gemini CLI vulnerabilities](https://www.cyera.com/research-labs/cyera-research-labs-discloses-command-prompt-injection-vulnerabilities-in-gemini-cli) and general prompt injection research.

---

### Pitfall 6: Claude Code Skill/Command Discovery and Character Budget Overflow

**What goes wrong:**
Claude Code has a 15,000-character budget for all registered skills. If the Kimi plugin registers multiple skills (analyze, audit, trace, verify) with detailed SKILL.md files, they can exceed this budget, causing some skills to be silently excluded from Claude's context. The user sees the slash commands in autocomplete but Claude has no knowledge of how to use them because the skill instructions were truncated.

Additionally, there is a known bug (#17271) where plugin skills with a `name` field in frontmatter lose their namespace prefix, causing command conflicts if multiple plugins use the same skill name.

**Why it happens:**
Claude Code loads skill frontmatter (name + description) for discovery but only loads full instructions when the budget allows. The description field is limited to 200 characters. If you have 5 skills each with 4,000 characters of instructions, you have already blown the 15,000-character budget. The existing Gemini SKILL.md is 102 lines -- multiply by 4 commands and the budget is exhausted.

**How to avoid:**
- Use ONE SKILL.md for the entire plugin, not separate skills per command. The single SKILL.md covers all roles and modes. This is how the existing Gemini integration works (one SKILL.md, multiple slash commands pointing to the same wrapper).
- Keep SKILL.md under 3,000 characters (not lines -- characters). Move detailed documentation to a separate reference file that the skill can read at runtime.
- Keep the `description` field under 200 characters but make it keyword-rich so Claude can auto-invoke correctly.
- Use slash commands (`.claude/commands/`) for user-facing invocation and a single skill for Claude-facing auto-invocation. This separates the "I want to type /kimi-analyze" concern from the "Claude should know when to delegate to Kimi" concern.
- Check the budget with `/context` command after installation.

**Warning signs:**
- `/context` shows warnings about excluded skills.
- Claude does not auto-invoke Kimi when it should (e.g., before reading a large codebase).
- Slash commands appear in autocomplete but Claude says "I don't know how to use that."
- Multiple plugins installed and only some skills work.

**Phase to address:**
Phase 3 (Slash commands and Claude Code integration) -- this is the integration surface and must be designed with budget awareness.

**Confidence:** HIGH -- verified from [Claude Code skills documentation](https://code.claude.com/docs/en/skills), [issue #17271](https://github.com/anthropics/claude-code/issues/17271), and [issue #16900](https://github.com/anthropics/claude-code/issues/16900).

---

## Technical Debt Patterns

Shortcuts that seem reasonable but create long-term problems.

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Hardcoding model names (e.g., `kimi-k2.5`) | Works today, no config needed | Breaks when model is deprecated or renamed (happened with Gemini wrapper's `gemini-3-pro-preview`) | Never -- always use a config variable with a default |
| Using `eval` for command construction | Easy to compose commands dynamically | Shell injection risk, impossible to audit, breaks with special characters in prompts | Never -- use bash arrays: `cmd=("kimi" "--quiet" "-p" "$prompt"); "${cmd[@]}"` |
| Sourcing config files with `source .kimi/config` | Simple key=value configuration | Arbitrary code execution if config contains malicious commands; silent failure on syntax errors | Never -- use a safer parser or just read environment variables |
| Dropping jq dependency to simplify install | One fewer prerequisite | Cannot safely construct or parse JSON; forced to use fragile sed/awk parsing | Acceptable only if no JSON handling is needed; Kimi YAML agent files use YAML not JSON, so jq may genuinely be unnecessary |
| Implementing spinner/progress UI in bash | Visual feedback for long operations | Orphaned background processes, terminal corruption on Ctrl-C, incompatible with non-interactive use by Claude Code | Never for a wrapper called by another AI -- Claude Code does not see spinners |

## Integration Gotchas

Common mistakes when connecting to external services.

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| Kimi CLI invocation | Using `eval` to construct the command string | Build a bash array and execute with `"${cmd[@]}"` to preserve quoting |
| Kimi CLI `--quiet` mode | Assuming stdout is clean text | `--quiet` may still emit warnings to stderr; always redirect stderr: `kimi --quiet -p "$prompt" 2>/dev/null` or capture stderr separately |
| Kimi CLI agent files | Putting agent YAML in one dir and prompts in another | Keep YAML and prompt files in a consistent directory tree; test after install |
| Claude Code slash commands | Creating separate SKILL.md per command | Use one SKILL.md for the whole plugin; use `.claude/commands/*.md` for individual slash commands |
| PowerShell shim | Assuming `bash` is always in PATH on Windows | Resolve bash.exe explicitly from known Git for Windows paths; provide clear error if not found |
| Kimi CLI authentication | Assuming API key is set via environment variable | Kimi uses OAuth login by default; API key is an alternative via `/setup` or `KIMI_API_KEY` env var; the wrapper should not assume either method |

## Performance Traps

Patterns that work at small scale but fail as usage grows.

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Loading entire git diff into prompt | Slow response, context overflow, increased API cost | Limit diff to changed files only (not full diff content) or use `--name-only` for large diffs | When diff exceeds 10,000 lines (common in large PRs or dependency updates) |
| Grep-based smart context (searching for keywords across all files) | Slow startup, irrelevant files included, prompt bloat | Let Kimi handle file discovery natively (it has its own Grep and Glob tools) -- do NOT re-implement this | On any codebase with >1,000 files |
| Re-reading context files on every invocation | Adds latency to every call | Context files are small and rarely change; the real risk is not latency but prompt size -- keep context files under 50KB | Not a performance issue, but a prompt budget issue at >50KB |

## Security Mistakes

Domain-specific security issues beyond general web security.

| Mistake | Risk | Prevention |
|---------|------|------------|
| `--quiet` implies `--yolo` (auto-approve all) for ALL agent operations | Kimi can execute shell commands, write files, make network requests without user approval | For analysis-only roles, use agent YAML with `exclude_tools` to remove Shell and FileWrite tools |
| Context files loaded from untrusted repositories | Second-order prompt injection: attacker controls context that shapes Kimi's behavior | Add `--no-context` flag; warn on large/suspicious context files; document trust model |
| Shell escaping in prompt passthrough | User prompt containing backticks or `$()` could be interpreted by bash before reaching Kimi | Always quote the prompt variable: `"$FULL_PROMPT"`, never use `eval` with user input |
| Config file sourcing (`source .kimi/config`) | Malicious config file executes arbitrary bash commands | Use environment variables or a simple key=value parser instead of sourcing |
| Logging prompts to files | Sensitive code or credentials in analyzed files end up in log files | Do not implement file logging; if needed, exclude it from version control and warn users |
| API key in environment visible to child processes | Kimi CLI (and any tool it calls) can read KIMI_API_KEY from environment | Not preventable in the wrapper; document that API key is accessible to all tools in the agent's toolset |

## UX Pitfalls

Common user experience mistakes in this domain.

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| Verbose output by default (spinners, color banners, status messages) | Claude Code sees and tries to parse decorative text as meaningful output | Default to quiet output (no color, no banners, no spinners); add `--verbose` for human use |
| Error messages without actionable guidance | User sees "kimi not found" and has to search for installation instructions | Every error message should include the fix: "kimi not found. Install with: uv tool install kimi-cli" |
| Requiring jq/bc/md5sum as hard dependencies | Users on minimal systems cannot install the wrapper | Eliminate all dependencies except bash and the kimi binary; YAML agent files do not need jq |
| Inconsistent flag naming between wrapper and kimi CLI | User learns `--role` in the wrapper but Kimi uses `--agent-file`; mental model clash | Use naming that maps clearly to Kimi concepts, or just pass flags through |
| Hardcoded output format that does not match what Claude Code expects | Claude Code gets a response it cannot parse; wastes tokens trying to understand formatting | Let Kimi output natural text; do not impose a rigid SUMMARY/FILES/ANALYSIS/RECOMMENDATIONS format from the wrapper side -- the agent's system prompt handles format |

## "Looks Done But Isn't" Checklist

Things that appear complete but are missing critical pieces.

- [ ] **Agent files work locally:** Test from the installed location (global and project), not just from the repo checkout -- path resolution is different
- [ ] **PowerShell shim passes all arguments:** Test with prompts containing spaces, quotes, backticks, newlines, and special characters ($, !, %) -- PowerShell escaping differs from bash
- [ ] **Install script handles existing installation:** Test upgrade path (files already exist), not just fresh install -- permission conflicts, backup logic, settings preservation
- [ ] **Kimi authentication works non-interactively:** `--quiet` mode should not trigger a login prompt; verify that the wrapper errors clearly if not authenticated
- [ ] **Git diff injection handles edge cases:** Test with binary files in diff, files with spaces in names, very large diffs (>50,000 lines), and repos with no commits
- [ ] **Wrapper works when called by Claude Code:** Claude Code calls the wrapper from a different working directory than the user expects; test with CWD set to the project root, not the wrapper's directory
- [ ] **Agent YAML validate against Kimi's schema:** An invalid YAML file causes a cryptic Python traceback, not a helpful error -- validate before calling kimi
- [ ] **Uninstaller removes everything:** Test that uninstall.sh removes agent files, slash commands, SKILL.md, and any generated state files without leaving orphans

## Recovery Strategies

When pitfalls occur despite prevention, how to recover.

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Kimi CLI version break | LOW | Pin version: `uv tool install kimi-cli==X.Y.Z`; document known-good version in README |
| PATH not found on Windows | LOW | Set `KIMI_PATH` env var to absolute path; update PowerShell shim to check explicit paths |
| Wrapper scope creep beyond 300 lines | MEDIUM | Audit every feature: does Kimi handle this natively? Remove wrapper features that duplicate Kimi functionality. Reset to minimal passthrough. |
| Agent file path resolution broken after install | LOW | Move prompt files next to YAML files; re-run installer; verify with `kimi --agent-file path/to/agent.yaml --quiet -p "test"` |
| Prompt injection via context file | HIGH | Remove untrusted context file; audit Kimi's actions via `~/.kimi/logs/kimi.log`; add `--no-context` to wrapper; review and restrict agent tool access |
| Claude Code skill budget exceeded | LOW | Consolidate to single SKILL.md under 3,000 chars; move details to separate reference file; verify with `/context` |
| Hardcoded model name deprecated | LOW | Change default in config; add env var override `KIMI_MODEL`; document in README |

## Pitfall-to-Phase Mapping

How roadmap phases should address these pitfalls.

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| Kimi CLI version instability | Phase 1: Core wrapper | Version check on startup; CI test against 2+ versions |
| Windows PATH / CLI Not Found | Phase 1: Core wrapper + Phase 4: Install | Test on Windows Git Bash and PowerShell after install; test after simulated PATH reset |
| Over-engineering / scope creep | All phases | Line count check: wrapper under 300 lines; feature-add requires updating OUT_OF_SCOPE.md |
| Agent file path resolution | Phase 2: Role/Agent system | Test agent invocation from both global and project install paths |
| Prompt injection via context | Phase 1: Context loading + Phase 2: Agent tools | Agent YAML for analysis roles excludes Shell/FileWrite; `--no-context` flag exists |
| Claude Code skill budget | Phase 3: Slash commands | Run `/context` after install; SKILL.md under 3,000 chars |
| Hardcoded model names | Phase 1: Core wrapper | Model name from env var or config, not hardcoded in script |
| Git Bash path mangling | Phase 1: Core wrapper | Test with paths containing spaces and Windows drive letters; use `MSYS_NO_PATHCONV=1` where needed |
| PowerShell argument escaping | Phase 4: Install + PowerShell shim | Test with prompts containing `$`, `!`, `"`, `'`, backticks from PowerShell |
| Kimi authentication in non-interactive mode | Phase 1: Core wrapper | Test `--quiet` when not logged in; verify error message is actionable |

## Sources

- [Kimi CLI GitHub Issues](https://github.com/MoonshotAI/kimi-cli/issues) -- bug tracker, 847+ issues
- [Issue #643: Kimi CLI performance regression v0.75 to v0.78](https://github.com/MoonshotAI/kimi-cli/issues/643) -- version instability evidence
- [Issue #800: VSCode plugin CLI Not Found after Windows update](https://github.com/MoonshotAI/kimi-cli/issues/800) -- Windows PATH issue
- [Issue #737: Session logout every 5 minutes](https://github.com/MoonshotAI/kimi-cli/issues/737) -- authentication instability
- [Issue #748: Install script does not update Kimi CLI](https://github.com/MoonshotAI/kimi-cli/issues/748) -- installation pitfall
- [Kimi CLI Agent Documentation](https://moonshotai.github.io/kimi-cli/en/customization/agents.html) -- agent YAML spec, path resolution
- [Kimi CLI Command Reference](https://www.kimi-cli.com/en/reference/kimi-command.html) -- --quiet, --print, --agent-file flags
- [Kimi CLI Troubleshooting (DeepWiki)](https://deepwiki.com/MoonshotAI/kimi-cli/12-troubleshooting) -- platform-specific issues
- [Kimi CLI FAQ](https://moonshotai.github.io/kimi-cli/en/faq.html) -- common problems
- [Claude Code Skills Documentation](https://code.claude.com/docs/en/skills) -- SKILL.md format, character budget
- [Claude Code Issue #17271: Plugin skills not showing in slash commands](https://github.com/anthropics/claude-code/issues/17271) -- skill registration bug
- [Claude Code Issue #16900: Skills vs commands confusion](https://github.com/anthropics/claude-code/issues/16900) -- post-v2.1.1 changes
- [Cyera Research Labs: Prompt injection in Gemini CLI](https://www.cyera.com/research-labs/cyera-research-labs-discloses-command-prompt-injection-vulnerabilities-in-gemini-cli) -- security vulnerability class
- [Avoid Load-bearing Shell Scripts (Ben Congdon)](https://benjamincongdon.me/blog/2023/10/29/Avoid-Load-bearing-Shell-Scripts/) -- scope creep antipattern
- [POSIX-to-Windows Path Conversion in Git Bash](https://gist.github.com/ddca05bcd9093e01532a550d5630230e) -- MSYS path mangling
- [BSD/macOS sed vs GNU sed (riptutorial)](https://riptutorial.com/sed/topic/9436/bsd-macos-sed-vs--gnu-sed-vs--the-posix-sed-specification) -- cross-platform sed pitfalls
- Existing codebase at `C:\Users\dasbl\Multi-Agent-Workflow\skills\gemini.agent.wrapper.sh` -- 1060 lines of evidence for scope creep
- Existing codebase concerns at `C:\Users\dasbl\Multi-Agent-Workflow\.planning\codebase\CONCERNS.md` -- documented tech debt

---
*Pitfalls research for: Kimi CLI wrapper plugin for Claude Code*
*Researched: 2026-02-04*
