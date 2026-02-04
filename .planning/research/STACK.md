# Stack Research

**Domain:** Claude Code plugin wrapping Kimi CLI as a code analysis companion
**Researched:** 2026-02-04
**Confidence:** MEDIUM (see per-section assessments below)

## Recommended Stack

### Core Technologies

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| Kimi CLI (`kimi-cli`) | 1.7.0 (2026-02-04) | LLM code analysis engine ("The Eyes") | Native agent YAML system, `--quiet` mode for clean scripted output, `--agent-file` for role injection, 1T-param K2.5 model with massive context. Actively maintained (7 releases in 8 days). |
| Bash (POSIX-compatible) | 4.0+ | Primary wrapper script | Cross-platform on macOS/Linux natively, Windows via Git Bash. The existing Gemini wrapper proves this approach works. |
| PowerShell (`pwsh`) | 7.0+ | Windows entry point | Resolves bash path on Windows (Git Bash), passes arguments through. Thin shim pattern proven by existing `gemini.ps1`. |
| Python | 3.13 (recommended by Kimi) | Kimi CLI runtime | Kimi CLI requires Python >=3.12. Python 3.13 is explicitly recommended in official docs. |
| `uv` | latest | Python tool installer | Official installation method: `uv tool install --python 3.13 kimi-cli`. Fast, reliable, no virtualenv management needed. |

### Kimi CLI: Verified Command-Line Interface

**Confidence: HIGH** (verified from official docs at moonshotai.github.io and DeepWiki)

#### Critical Flags for Our Wrapper

| Flag | Type | Description | Wrapper Use |
|------|------|-------------|-------------|
| `--quiet` | boolean | Shortcut for `--print --output-format text --final-message-only` | **PRIMARY MODE.** Clean text output, only final message. No TUI chrome. This is our default invocation mode. |
| `--print` | boolean | Non-interactive mode, implicitly enables `--yolo` (auto-approve) | Used internally by `--quiet`. Enables scripted usage. |
| `--prompt TEXT` / `-p` | string | Pass user prompt, does not enter interactive mode | How we send the analysis query. |
| `--agent-file PATH` | path | Load custom agent YAML file | **KEY FEATURE.** How we inject roles (reviewer, debugger, planner, etc.) |
| `--model NAME` / `-m` | string | Override default model from config | Allow users to select models per-invocation. |
| `--thinking` / `--no-thinking` | boolean | Enable/disable thinking mode | Toggleable deep reasoning for complex analysis. |
| `--yolo` / `-y` / `--yes` | boolean | Auto-approve all operations | Already implied by `--quiet`, but explicit for `--print` mode. |
| `--output-format FORMAT` | enum | `text` (default) or `stream-json` | `text` for our use; `stream-json` for future programmatic parsing. |
| `--final-message-only` | boolean | Only output the final assistant message | Already implied by `--quiet`. Strips intermediate tool-call noise. |
| `--work-dir PATH` / `-w` | path | Specify working directory | Override cwd for analysis scope. |
| `--config-file PATH` | path | Custom config file (TOML or JSON) | Support project-specific configurations. |
| `--session ID` / `-S` | string | Resume or create named session | Future: conversation continuity for multi-turn analysis. |
| `--continue` / `-C` | boolean | Continue previous session in cwd | Future: follow-up queries. |
| `--skills-dir PATH` | path | Custom skills directory | Can point at our plugin's skills directory. |
| `--mcp-config-file PATH` | path | MCP server configuration | Future: extend with MCP tools. |
| `--max-steps-per-turn N` | integer | Limit agent steps (default 100) | Safety limit for analysis-only use. |
| `--debug` | boolean | Debug logging to `~/.kimi/logs/kimi.log` | Troubleshooting wrapper issues. |

#### Deprecated Flags (Avoid)

| Flag | Status | Use Instead |
|------|--------|-------------|
| `--command` / `-c` | Deprecated alias | `--prompt` / `-p` |
| `--query` / `-q` | Removed in v0.77 | `--prompt` / `-p` |
| `--acp` | Deprecated | `kimi acp` subcommand |

### Kimi CLI: Agent YAML Format

**Confidence: HIGH** (verified from official docs)

#### Complete YAML Schema

```yaml
version: 1
agent:
  # Inherit from built-in agent or relative path to another YAML
  extend: default  # "default" or "./path/to/base.yaml"

  # Agent identifier
  name: my-agent

  # System prompt file (path relative to this YAML file)
  system_prompt_path: ./system-prompt.md

  # Custom variables injected into system prompt template
  system_prompt_args:
    MY_VAR: "custom value"
    ROLE_DESCRIPTION: "You are a security auditor"

  # Tools available to this agent (module:ClassName format)
  tools:
    - "kimi_cli.tools.file:ReadFile"
    - "kimi_cli.tools.file:Glob"
    - "kimi_cli.tools.file:Grep"
    - "kimi_cli.tools.shell:Shell"

  # Tools to remove from inherited agent
  exclude_tools:
    - "kimi_cli.tools.web:SearchWeb"
    - "kimi_cli.tools.shell:Shell"

  # Subagent definitions
  subagents:
    coder:
      path: ./coder-sub.yaml
      description: "Handle coding tasks"
```

#### Built-in System Prompt Variables

| Variable | Content | Use |
|----------|---------|-----|
| `${KIMI_NOW}` | Current time (ISO format) | Timestamp in prompts |
| `${KIMI_WORK_DIR}` | Working directory path | Reference project root |
| `${KIMI_WORK_DIR_LS}` | Working directory file listing | Auto-inject project structure |
| `${KIMI_AGENTS_MD}` | AGENTS.md content (if exists) | Project conventions |
| `${KIMI_SKILLS}` | Loaded skills list | Available capabilities |

Custom variables from `system_prompt_args` are also available via `${VAR_NAME}` syntax.

#### Available Tool Import Paths (15 tools)

| Category | Tool | Import Path |
|----------|------|-------------|
| **File** | ReadFile | `kimi_cli.tools.file:ReadFile` |
| **File** | ReadMediaFile | `kimi_cli.tools.file:ReadMediaFile` |
| **File** | WriteFile | `kimi_cli.tools.file:WriteFile` |
| **File** | StrReplaceFile | `kimi_cli.tools.file:StrReplaceFile` |
| **File** | Glob | `kimi_cli.tools.file:Glob` |
| **File** | Grep | `kimi_cli.tools.file:Grep` |
| **Shell** | Shell | `kimi_cli.tools.shell:Shell` |
| **Web** | SearchWeb | `kimi_cli.tools.web:SearchWeb` |
| **Web** | FetchURL | `kimi_cli.tools.web:FetchURL` |
| **Think** | Think | `kimi_cli.tools.think:Think` |
| **Todo** | SetTodoList | `kimi_cli.tools.todo:SetTodoList` |
| **Multi-Agent** | Task | `kimi_cli.tools.multiagent:Task` |
| **Multi-Agent** | CreateSubagent | `kimi_cli.tools.multiagent:CreateSubagent` |
| **Communication** | SendDMail | `kimi_cli.tools.dmail:SendDMail` |
| **External** | MCP tools | Via `--mcp-config-file` |

#### Recommended Tool Set for Analysis-Only Agents

For code analysis (read-only "Eyes" role), restrict tools to prevent modifications:

```yaml
tools:
  - "kimi_cli.tools.file:ReadFile"
  - "kimi_cli.tools.file:ReadMediaFile"
  - "kimi_cli.tools.file:Glob"
  - "kimi_cli.tools.file:Grep"
  - "kimi_cli.tools.think:Think"
```

Explicitly exclude dangerous tools for analysis roles:

```yaml
extend: default
exclude_tools:
  - "kimi_cli.tools.file:WriteFile"
  - "kimi_cli.tools.file:StrReplaceFile"
  - "kimi_cli.tools.shell:Shell"
  - "kimi_cli.tools.multiagent:Task"
  - "kimi_cli.tools.multiagent:CreateSubagent"
  - "kimi_cli.tools.web:SearchWeb"
  - "kimi_cli.tools.web:FetchURL"
  - "kimi_cli.tools.dmail:SendDMail"
  - "kimi_cli.tools.todo:SetTodoList"
```

### Kimi CLI: Model Configuration

**Confidence: MEDIUM** (model names verified from docs examples + web search, but exact default model after `/login` not confirmed)

#### Known Model Identifiers

| Model Name | Provider | Capabilities | Notes |
|------------|----------|-------------|-------|
| `kimi-k2-thinking-turbo` | `kimi` / `moonshot-cn` | `always_thinking` | Thinking model, always reasons. Referenced in official docs. |
| (Kimi Code default) | `kimi` (OAuth) | varies | Set automatically via `/login` with Kimi Code platform. Exact default model name not documented publicly. |

#### Provider Configuration in `~/.kimi/config.toml`

```toml
# Kimi Code (OAuth) - recommended, auto-configured via /login
[providers.kimi-for-coding]
type = "kimi"
base_url = "https://api.kimi.com/coding/v1"
api_key = "sk-xxx"

# Moonshot AI Open Platform - manual API key
[providers.moonshot]
type = "kimi"
base_url = "https://api.moonshot.cn/v1"
api_key = "sk-xxx"

# OpenAI-compatible provider
[providers.openai]
type = "openai_legacy"
base_url = "https://api.openai.com/v1"
api_key = "sk-xxx"

# Anthropic
[providers.anthropic]
type = "anthropic"
base_url = "https://api.anthropic.com"
api_key = "sk-ant-xxx"

# Google Gemini
[providers.gemini]
type = "gemini"
base_url = "https://generativelanguage.googleapis.com"
api_key = "xxx"
```

#### Model Definition Example

```toml
[models.kimi-k2-thinking-turbo]
provider = "moonshot-cn"
model = "kimi-k2-thinking-turbo"
max_context_size = 131072
capabilities = ["always_thinking"]

[models.gemini-3-pro-preview]
provider = "gemini"
model = "gemini-3-pro-preview"
max_context_size = 262144
capabilities = ["thinking", "image_in"]
```

#### Model Capabilities

| Capability | Effect |
|-----------|--------|
| `thinking` | Supports toggleable deep reasoning (via `--thinking` flag) |
| `always_thinking` | Always uses deep reasoning (cannot disable) |
| `image_in` | Accepts image input |
| `video_in` | Accepts video input |

**NOTE:** The exact model names available via Kimi Code OAuth (the recommended provider) are configured automatically during `/login`. The wrapper should not hardcode model names -- instead use `--model` flag to let users override, or rely on the user's `config.toml` default. This is a key architectural decision: let Kimi CLI handle model selection natively.

### Kimi CLI: Skills System

**Confidence: HIGH** (verified from official docs)

Skills are auto-discovered from these directories (priority order):

**User-level:** `~/.config/agents/skills/` (recommended), `~/.agents/skills/`, `~/.kimi/skills/`, `~/.claude/skills/`, `~/.codex/skills/`

**Project-level:** `.agents/skills/` (recommended), `.kimi/skills/`, `.claude/skills/`, `.codex/skills/`

**Custom:** `--skills-dir PATH` flag overrides auto-discovery entirely.

**SKILL.md format:**
```yaml
---
name: skill-identifier
description: What this skill does
---

## Skill Content
[Markdown instructions and guidance]
```

### Claude Code Plugin Structure

**Confidence: HIGH** (verified from official Claude Code plugin docs)

#### Standard Plugin Layout

```
kimi-context-companion/
  .claude-plugin/
    plugin.json              # Required: manifest
  commands/
    kimi-analyze.md          # /kimi-analyze slash command
    kimi-trace.md            # /kimi-trace slash command
    kimi-verify.md           # /kimi-verify slash command
    kimi-audit.md            # /kimi-audit slash command
  agents/
    kimi-research.md         # Kimi-powered analysis agent
  skills/
    kimi-research/
      SKILL.md               # Skill definition
  hooks/
    hooks.json               # Event handlers (optional)
  scripts/
    kimi.sh                  # Main bash wrapper
    kimi.ps1                 # Windows PowerShell shim
  .kimi/
    agents/
      reviewer.yaml          # Role: code reviewer
      debugger.yaml          # Role: bug tracer
      planner.yaml           # Role: architecture planner
      security.yaml          # Role: security auditor
      explainer.yaml         # Role: code explainer
    prompts/
      reviewer.md            # System prompt for reviewer
      debugger.md            # System prompt for debugger
      planner.md             # System prompt for planner
      security.md            # System prompt for security
      explainer.md           # System prompt for explainer
    templates/
      feature.md             # Feature analysis template
      bug.md                 # Bug investigation template
      verify.md              # Post-change verification template
  KimiContext.md             # Project context injection file
```

#### plugin.json Manifest

```json
{
  "name": "kimi-context-companion",
  "version": "1.0.0",
  "description": "Kimi CLI integration for large-context code analysis",
  "author": {
    "name": "dasbl"
  },
  "repository": "https://github.com/dasbl/Multi-Agent-Workflow",
  "license": "Apache-2.0",
  "keywords": ["kimi", "code-analysis", "context-companion", "multi-agent"]
}
```

#### Key Plugin Environment Variable

`${CLAUDE_PLUGIN_ROOT}` -- absolute path to the installed plugin directory. Use in hooks and scripts for portable paths.

### Supporting Libraries / Dependencies

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `jq` | latest | JSON parsing (optional) | Only if we support `--output-format stream-json` parsing. The Gemini wrapper required it; the Kimi wrapper may not need it since `--quiet` gives plain text. |
| `git` | any | Diff injection | When using `--diff` flag for verification workflows. Standard on dev machines. |
| `uv` | latest | Python tool manager | Kimi CLI installation. Auto-installed by Kimi's official install script. |

### Development Tools

| Tool | Purpose | Notes |
|------|---------|-------|
| `shellcheck` | Bash script linting | Run on CI; catches portability issues between bash versions |
| `PSScriptAnalyzer` | PowerShell linting | Optional; validates .ps1 shim |
| Claude Code | Plugin testing | Test plugin installation with `claude plugin install` |

## Installation

```bash
# Install Kimi CLI (official method)
curl -LsSf https://code.kimi.com/install.sh | bash

# Or via uv (explicit Python version)
uv tool install --python 3.13 kimi-cli

# Windows (PowerShell)
Invoke-RestMethod https://code.kimi.com/install.ps1 | Invoke-Expression

# Verify installation
kimi --version

# First-time setup (interactive, opens browser for OAuth)
kimi
# Then type: /login

# Upgrade
uv tool upgrade kimi-cli --no-cache

# Uninstall
uv tool uninstall kimi-cli
```

## Alternatives Considered

| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|-------------------------|
| `--quiet` mode (text output) | `--print --output-format stream-json` | When programmatic parsing of intermediate steps is needed (future enhancement) |
| `--agent-file` YAML for roles | Hardcoded system prompts in bash | Never -- YAML agents are cleaner, maintainable, and use Kimi's native system |
| `extend: default` in agent YAML | Full tool list per agent | Always inherit from default and use `exclude_tools` for analysis-only roles |
| Kimi Code OAuth provider | Manual Moonshot API key | When user needs specific model control or is behind a firewall |
| Bash wrapper + PowerShell shim | Pure PowerShell wrapper | Never -- bash is the canonical implementation; .ps1 just bridges to it |
| Claude Code plugin format | Legacy `.claude/` directory approach | The plugin format with `.claude-plugin/plugin.json` is the official v2.1+ format for distributable plugins |

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| `--query` / `-q` flag | Removed in Kimi CLI v0.77 | `--prompt` / `-p` |
| `--command` / `-c` flag | Deprecated alias | `--prompt` / `-p` |
| `--acp` flag | Deprecated | `kimi acp` subcommand |
| Hardcoded model names in wrapper | Models change frequently; user configures via `/login` | `--model` flag as optional override, else use config default |
| `WriteFile` / `StrReplaceFile` / `Shell` tools in analysis agents | These allow modifications; analysis should be read-only | Explicit `exclude_tools` in agent YAML |
| `jq` as hard dependency | Kimi's `--quiet` mode outputs clean text; no JSON parsing needed for basic use | Direct text output; make `jq` optional |
| Gemini-style `@dir/` syntax for context | Kimi CLI does not use this; it reads files via its own tool system | Let Kimi's agent tools (ReadFile, Glob, Grep) handle file discovery |

## Stack Patterns by Variant

**If user wants read-only analysis (default):**
- Use `--quiet` mode with agent YAML that excludes write/shell tools
- Kimi reads code, returns analysis text, Claude acts on it

**If user wants Kimi to also suggest fixes:**
- Use `--quiet` mode but include `WriteFile` in agent tools
- Add `--yolo` for auto-approval (already implied by `--quiet`)
- Parse output for suggested code changes

**If user wants streaming output:**
- Use `--print --output-format stream-json` instead of `--quiet`
- Parse JSONL output line-by-line
- Requires `jq` or similar JSON parser

**If user wants multi-turn conversation:**
- Use `--session ID` flag to maintain context across calls
- Follow up with `--continue` flag
- Useful for iterative debugging sessions

## Version Compatibility

| Package | Compatible With | Notes |
|---------|-----------------|-------|
| `kimi-cli` >= 1.0 | Python >= 3.12 | Python 3.13 recommended |
| `kimi-cli` >= 1.7.0 | `--quiet` flag | Shortcut added; verify in changelog if using older version |
| `--agent-file` | `kimi-cli` >= 1.0 | Core feature since initial release |
| Claude Code plugins | Claude Code v2.1+ | Plugin format with `.claude-plugin/plugin.json` |
| Bash wrapper | Git Bash 4.0+ (Windows) | Windows users need Git for Windows installed |
| PowerShell shim | `pwsh` 7.0+ | Cross-platform PowerShell; Windows PowerShell 5.1 may work but untested |

## Key Design Decision: --quiet vs Gemini Wrapper Approach

The existing Gemini wrapper constructs a massive prompt by concatenating context files, role prompts, templates, git diffs, and directory contents into a single string, then pipes it to `gemini` CLI. This works because Gemini CLI is essentially a simple API wrapper.

**Kimi CLI is fundamentally different.** It is a full agentic system with its own:
- File reading tools (ReadFile, Glob, Grep)
- Agent specification system (YAML + system prompts)
- Session management
- Auto-approval gates
- Tool execution loop

**The Kimi wrapper should be much thinner** than the Gemini wrapper because:
1. **Roles** map to `--agent-file` YAML files (not bash string concatenation)
2. **Context injection** uses `KimiContext.md` / `AGENTS.md` (Kimi reads these natively)
3. **File analysis** is done by Kimi's own tools (not by concatenating file contents into the prompt)
4. **Output formatting** is handled by `--quiet` (not by parsing/reformatting)

The wrapper primarily needs to:
- Select the right `--agent-file` based on the `-r` role flag
- Inject git diff into the prompt text when `--diff` is requested
- Pass through the user's query via `--prompt`
- Handle the `--quiet` flag for clean output
- Provide error handling and dependency checking

## Sources

### Official Documentation (HIGH confidence)
- [Kimi CLI Getting Started](https://moonshotai.github.io/kimi-cli/en/guides/getting-started.html) -- installation, setup
- [Kimi CLI Agents and Subagents](https://moonshotai.github.io/kimi-cli/en/customization/agents.html) -- agent YAML format, tools, variables
- [Kimi CLI Providers and Models](https://moonshotai.github.io/kimi-cli/en/configuration/providers.html) -- provider types, model config
- [Kimi CLI Config Files](https://moonshotai.github.io/kimi-cli/en/configuration/config-files.html) -- config.toml structure
- [Kimi CLI Skills](https://moonshotai.github.io/kimi-cli/en/customization/skills.html) -- SKILL.md format, discovery
- [Kimi CLI Slash Commands](https://moonshotai.github.io/kimi-cli/en/reference/slash-commands.html) -- /model, /login, /init
- [Kimi CLI Command Reference](https://www.kimi-cli.com/en/reference/kimi-command.html) -- complete CLI flags
- [Claude Code Plugins Reference](https://code.claude.com/docs/en/plugins-reference) -- plugin structure, manifest, hooks

### GitHub / PyPI (HIGH confidence)
- [Kimi CLI GitHub](https://github.com/MoonshotAI/kimi-cli) -- source, README, AGENTS.md
- [Kimi CLI PyPI](https://pypi.org/project/kimi-cli/) -- version 1.7.0, release dates, Python requirement

### Community / Analysis (MEDIUM confidence)
- [DeepWiki: Kimi CLI Architecture](https://deepwiki.com/MoonshotAI/kimi-cli) -- architecture overview, CLI flags
- [DeepWiki: Command-Line Options](https://deepwiki.com/MoonshotAI/kimi-cli/2.3-command-line-options-reference) -- comprehensive flag reference

### Model Information (MEDIUM confidence)
- [Kimi K2.5 HuggingFace](https://huggingface.co/moonshotai/Kimi-K2.5) -- model specs
- [Kimi K2.5 Announcement](https://techcrunch.com/2026/01/27/chinas-moonshot-releases-a-new-open-source-model-kimi-k2-5-and-a-coding-agent/) -- release context

### Gaps Requiring Validation
- **Exact default model name** after Kimi Code OAuth login: not publicly documented. Must test by running `kimi /login` and inspecting `~/.kimi/config.toml`. [LOW confidence]
- **`--quiet` flag availability**: referenced in DeepWiki and kimi-cli.com command reference, but exact version it was introduced is unclear. Test with `kimi --quiet --prompt "hello"`. [MEDIUM confidence]
- **Kimi K2.5 model identifier in config.toml**: likely `kimi-k2.5` but not confirmed from CLI docs directly. The platform API uses "kimi-k2.5" per HuggingFace. [LOW confidence]

---
*Stack research for: Claude Code plugin wrapping Kimi CLI as a context companion*
*Researched: 2026-02-04*
