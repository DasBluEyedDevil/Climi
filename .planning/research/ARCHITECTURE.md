# Architecture Research

**Domain:** Claude Code plugin with Kimi CLI integration (CLI wrapper + agent system)
**Researched:** 2026-02-04
**Confidence:** HIGH (based on existing codebase analysis + official Kimi CLI docs + Claude Code docs)

## System Overview

```
+-----------------------------------------------------------------------+
|                        Claude Code (Host)                             |
|  +-----------------+  +--------------------+  +--------------------+  |
|  | /kimi-analyze   |  | /kimi-trace        |  | /kimi-verify       |  |
|  | (slash command) |  | (slash command)    |  | (slash command)    |  |
|  +--------+--------+  +---------+----------+  +---------+----------+  |
|           |                     |                       |             |
|           +---------------------+-----------------------+             |
|                                 |                                     |
|  +------------------------------v-------------------------------+     |
|  |              SKILL.md (teaches Claude when/how)              |     |
|  +------------------------------+-------------------------------+     |
|                                 |                                     |
|           (Claude invokes via Bash tool)                              |
+-------------------------------------+--------------------------------+
                                      |
+-------------------------------------v--------------------------------+
|                    kimi.agent.wrapper.sh                              |
|  +-------------+  +-------------+  +-------------+  +-------------+  |
|  | Arg Parser  |  | Role        |  | Template    |  | Diff/Context|  |
|  |             |  | Resolver    |  | Applier     |  | Injector    |  |
|  +------+------+  +------+------+  +------+------+  +------+------+  |
|         |                |                |                |          |
|         +----------------+----------------+----------------+          |
|                          |                                            |
|              +-----------v-----------+                                |
|              | kimi CLI invocation   |                                |
|              | --agent-file --quiet  |                                |
|              | -p "assembled prompt" |                                |
|              +-----------+-----------+                                |
+---------------------------+------------------------------------------+
                            |
+---------------------------v------------------------------------------+
|                         Kimi CLI (Native)                            |
|  +------------------+  +------------------+  +------------------+    |
|  | Agent System     |  | Tool System      |  | Session Mgmt     |    |
|  | (YAML + .md)     |  | (Shell, File,    |  | (--continue,     |    |
|  |                  |  |  Web, Grep, etc) |  |  --session)      |    |
|  +------------------+  +------------------+  +------------------+    |
|  +------------------+  +------------------+                          |
|  | Model Selection  |  | Output Modes     |                          |
|  | (K2.5, etc.)     |  | (--quiet, --print|                          |
|  +------------------+  |  --final-msg-only|                          |
|                        +------------------+                          |
+----------------------------------------------------------------------+
```

### Component Responsibilities

| Component | Responsibility | Typical Implementation |
|-----------|----------------|------------------------|
| Slash Commands | User-facing entry points in Claude Code; invoke the wrapper with role/template presets | `.claude/commands/kimi/*.md` files with frontmatter |
| SKILL.md | Teaches Claude Code when and how to invoke Kimi; injected into Claude's system prompt | `.claude/skills/kimi-research/SKILL.md` |
| Wrapper Script | Thin orchestration: parse args, resolve role, apply template, inject diff/context, invoke `kimi` CLI | `skills/kimi.agent.wrapper.sh` (~150-250 lines target) |
| PowerShell Shim | Windows compatibility layer; finds bash, converts paths, delegates to wrapper | `skills/kimi.ps1` |
| Agent YAML Files | Kimi-native role definitions; specify system prompt path, tool access, inheritance | `.kimi/agents/*.yaml` |
| System Prompt Files | Markdown files defining each role's persona and output format | `.kimi/agents/prompts/*.md` |
| Templates | Prompt patterns for common queries (feature, bug, verify, etc.) | `.kimi/templates/*.md` |
| Context File | Project-specific rules auto-injected into every query | `KimiContext.md` |
| Installer | Deploy all components to global or project location | `install.sh` |
| Uninstaller | Clean removal of all installed components | `uninstall.sh` |

## Recommended Project Structure

```
Multi-Agent-Workflow/
|-- .claude/
|   |-- commands/
|   |   +-- kimi/                     # Slash command namespace
|   |       |-- kimi-analyze.md       # /project:kimi:kimi-analyze
|   |       |-- kimi-audit.md         # /project:kimi:kimi-audit
|   |       |-- kimi-trace.md         # /project:kimi:kimi-trace
|   |       +-- kimi-verify.md        # /project:kimi:kimi-verify
|   |-- settings.json                 # enabledSkills
|   +-- skills/
|       +-- kimi-research/
|           +-- SKILL.md              # Claude Code skill definition
|
|-- .kimi/                            # Kimi-specific config (NOT .gemini)
|   |-- agents/                       # Role agent YAML files
|   |   |-- prompts/                  # System prompt markdown files
|   |   |   |-- reviewer.md
|   |   |   |-- debugger.md
|   |   |   |-- planner.md
|   |   |   |-- security.md
|   |   |   |-- auditor.md
|   |   |   |-- explainer.md
|   |   |   |-- migrator.md
|   |   |   |-- documenter.md
|   |   |   |-- dependency-mapper.md
|   |   |   |-- onboarder.md
|   |   |   |-- api-designer.md
|   |   |   |-- database-expert.md
|   |   |   |-- kotlin-expert.md
|   |   |   |-- typescript-expert.md
|   |   |   +-- python-expert.md
|   |   |-- reviewer.yaml
|   |   |-- debugger.yaml
|   |   |-- planner.yaml
|   |   |-- security.yaml
|   |   |-- auditor.yaml
|   |   |-- explainer.yaml
|   |   |-- migrator.yaml
|   |   |-- documenter.yaml
|   |   |-- dependency-mapper.yaml
|   |   |-- onboarder.yaml
|   |   |-- api-designer.yaml
|   |   |-- database-expert.yaml
|   |   |-- kotlin-expert.yaml
|   |   |-- typescript-expert.yaml
|   |   +-- python-expert.yaml
|   +-- templates/                    # Query templates (markdown)
|       |-- feature.md
|       |-- bug.md
|       |-- verify.md
|       |-- architecture.md
|       |-- implement-ready.md
|       +-- fix-ready.md
|
|-- skills/
|   |-- kimi.agent.wrapper.sh         # Main wrapper script
|   |-- kimi.ps1                      # PowerShell shim for Windows
|   +-- Claude-Code-Integration.md    # Integration documentation
|
|-- KimiContext.md                     # Project context injection file
|-- install.sh                        # Installer
|-- uninstall.sh                      # Uninstaller
|-- README.md                         # Public documentation
+-- docs/                             # Extended documentation
```

### Structure Rationale

- **`.kimi/agents/` for agent YAMLs:** Kimi CLI natively looks in `.kimi/` for project config. Keeping agents here means Kimi's own discovery can find them. The `prompts/` subdirectory keeps system prompt markdown separate from YAML specs -- a clean separation Kimi's `system_prompt_path` field was designed for.

- **`.kimi/templates/` for templates:** Templates are NOT Kimi agent files -- they are prompt fragments the wrapper prepends. They live in `.kimi/` alongside agents because they are Kimi-integration-specific, but they are loaded by the wrapper, not by Kimi itself.

- **`.claude/commands/kimi/` for slash commands:** Claude Code requires commands in `.claude/commands/`. The `kimi/` subdirectory creates namespace separation so commands show as `/project:kimi:kimi-analyze`. This avoids conflicts with other plugins.

- **`skills/` at repo root for the wrapper:** Matches the existing convention from the Gemini version. The wrapper script and PowerShell shim live here. On global install, these copy to `~/.claude/skills/`.

- **Agent YAML + Prompt pairs:** Each role is a YAML file (specifying tools, inheritance, prompt path) plus a corresponding `.md` file in `prompts/`. This is the Kimi-native pattern. The YAML is tiny (~10-15 lines); the prompt is where the role definition lives.

## Architectural Patterns

### Pattern 1: Thin Wrapper, Thick Native Agent

**What:** The bash wrapper does as little as possible. Role definition, tool selection, session management, model selection, and output formatting are all handled by Kimi CLI natively via `--agent-file`, `--quiet`, `--model`, etc. The wrapper only handles concerns Kimi cannot: template application, git diff injection, context file loading, and role resolution (project vs global path).

**When to use:** Always. This is the core architectural principle for the new design.

**Trade-offs:**
- Pro: Wrapper stays under 250 lines (vs 1060 in Gemini version)
- Pro: New Kimi CLI features automatically available without wrapper changes
- Pro: Agent files are testable independently (`kimi --agent-file agents/reviewer.yaml -p "test"`)
- Con: Less control over exact prompting behavior (Kimi adds its own system prompt via `extend: default`)
- Con: Debugging requires understanding both wrapper and Kimi's agent resolution

**Example:**
```bash
# Gemini wrapper (old approach): wrapper builds entire prompt
FULL_PROMPT="${CONTEXT}\n${ROLE_CONTENT}\n${TEMPLATE}\n${DIFF}\n${USER_QUERY}"
gemini -m "$MODEL" "$FULL_PROMPT"

# Kimi wrapper (new approach): wrapper passes role to Kimi natively
AGENT_FILE=$(resolve_agent "$ROLE")  # finds .kimi/agents/reviewer.yaml
kimi --agent-file "$AGENT_FILE" --quiet -p "$ASSEMBLED_PROMPT"
# Role personality is in the YAML/prompt file, not injected by wrapper
```

### Pattern 2: Two-Tier Role Resolution (Project then Global)

**What:** When the user specifies `-r reviewer`, the wrapper first looks for `.kimi/agents/reviewer.yaml` in the current project directory, then falls back to the global install location (e.g., `~/.claude/.kimi/agents/reviewer.yaml` for global installs). Project roles override global roles.

**When to use:** Every role lookup. This is essential for allowing per-project role customization while having sensible defaults.

**Trade-offs:**
- Pro: Users can customize roles per project without modifying the global install
- Pro: Global defaults mean it works out of the box after install
- Con: Debugging "which agent file was used" requires checking both locations

**Example:**
```bash
resolve_agent() {
    local role="$1"
    # Project-local agent takes priority
    if [ -f ".kimi/agents/${role}.yaml" ]; then
        echo ".kimi/agents/${role}.yaml"
        return 0
    fi
    # Fall back to global install
    if [ -f "$GLOBAL_KIMI_DIR/agents/${role}.yaml" ]; then
        echo "$GLOBAL_KIMI_DIR/agents/${role}.yaml"
        return 0
    fi
    return 1  # Role not found
}
```

### Pattern 3: Template as Prompt Prefix, Not Agent Property

**What:** Templates (feature, bug, verify, etc.) are prompt fragments loaded by the wrapper and prepended to the user's query. They are NOT part of the Kimi agent file. This separation keeps templates reusable across roles.

**When to use:** Whenever `-t template` is specified. A user can combine any role with any template: `-r security -t verify` is valid.

**Trade-offs:**
- Pro: Any role can use any template (orthogonal concerns)
- Pro: Templates are simple markdown files -- easy to edit
- Con: Template content is not visible to Kimi's agent system (it's just part of the prompt text)

**Example:**
```bash
# Template file: .kimi/templates/verify.md
# Contains structured verification request text

# Wrapper assembles: template + diff + user prompt
# Then passes to kimi which applies the agent's system prompt on top
PROMPT="${TEMPLATE_CONTENT}\n${DIFF_CONTENT}\n${USER_QUERY}"
kimi --agent-file "$AGENT_FILE" --quiet -p "$PROMPT"
```

### Pattern 4: Agent Tool Scoping for Safety

**What:** Analysis-only roles (reviewer, explainer, auditor) use `exclude_tools` to remove write/execute capabilities. Action roles (migrator, fixer) retain full tools. This is defined in the YAML agent file using Kimi's native `exclude_tools` field.

**When to use:** Every agent definition must explicitly decide on tool access.

**Trade-offs:**
- Pro: Prevents accidental file modification during analysis-only tasks
- Pro: Security roles cannot execute arbitrary shell commands
- Pro: Kimi-native mechanism (not wrapper-level enforcement)
- Con: If user calls kimi directly without the agent file, no tool restriction applies

**Example:**
```yaml
# .kimi/agents/reviewer.yaml (read-only)
version: 1
agent:
  extend: default
  name: reviewer
  system_prompt_path: ./prompts/reviewer.md
  exclude_tools:
    - "kimi_cli.tools.shell:Shell"
    - "kimi_cli.tools.file:WriteFile"
    - "kimi_cli.tools.file:StrReplaceFile"

# .kimi/agents/migrator.yaml (full access)
version: 1
agent:
  extend: default
  name: migrator
  system_prompt_path: ./prompts/migrator.md
  # No exclude_tools -- migrator needs full access
```

### Pattern 5: Context Injection via Prompt, Not Agent File

**What:** The `KimiContext.md` file is loaded by the wrapper and prepended to the prompt, NOT referenced in the agent YAML's `system_prompt_path`. This is because the context file is per-project and mutable, while agent files are per-install and stable.

**When to use:** Every invocation. The wrapper checks multiple locations for the context file (same pattern as Gemini wrapper).

**Trade-offs:**
- Pro: Context file changes take effect immediately without touching agent files
- Pro: Different projects can have different contexts with the same agent files
- Con: Context is part of the user prompt, not the system prompt (slightly less authoritative in Kimi's prompt hierarchy)
- Note: Kimi also has its own `AGENTS.md` context mechanism that users may additionally use

**Considered alternative:** Using Kimi's `system_prompt_args` to inject context. Rejected because that requires modifying the system prompt template to reference a variable, and the context file path differs per project.

## Data Flow

### Primary Invocation Flow

```
User types: /kimi-analyze @src/ How is authentication implemented?
    |
    v
Claude Code reads: .claude/commands/kimi/kimi-analyze.md
    |
    v
Claude Code sees instructions in command file:
    "Run kimi.agent.wrapper.sh with appropriate flags"
    |
    v
Claude executes via Bash tool:
    skills/kimi.agent.wrapper.sh -d "@src/" "How is authentication implemented?"
    |
    v
Wrapper: parse_arguments()
    |-- role = "" (none specified in analyze command, or default)
    |-- template = "" (none)
    |-- directories = "@src/"
    |-- prompt = "How is authentication implemented?"
    |-- diff = false
    |
    v
Wrapper: load_context()
    |-- Check: .kimi/KimiContext.md
    |-- Check: KimiContext.md
    |-- Check: $GLOBAL_KIMI_DIR/KimiContext.md
    |-- Result: context text or empty string
    |
    v
Wrapper: resolve_agent() [if -r flag was used]
    |-- Check: .kimi/agents/{role}.yaml
    |-- Check: $GLOBAL_KIMI_DIR/agents/{role}.yaml
    |-- Result: agent file path or error
    |
    v
Wrapper: load_template() [if -t flag was used]
    |-- Check: .kimi/templates/{template}.md
    |-- Check: $GLOBAL_KIMI_DIR/templates/{template}.md
    |-- Result: template text or error
    |
    v
Wrapper: inject_diff() [if --diff flag was used]
    |-- Run: git diff HEAD
    |-- Run: git diff --name-only HEAD
    |-- Result: diff text prepended to prompt
    |
    v
Wrapper: assemble_prompt()
    |-- combined = context + template + diff + user_prompt
    |
    v
Wrapper: invoke_kimi()
    |-- kimi [--agent-file AGENT] --quiet -p "COMBINED_PROMPT"
    |-- stdout captured and returned
    |
    v
Claude receives Kimi's analysis output
    |
    v
Claude acts on the analysis (implements, fixes, etc.)
```

### Slash Command Invocation Variants

```
/kimi-analyze [dir] [question]
    --> wrapper -d "@dir/" "question"
    --> no role, no template, just analysis

/kimi-trace [dir] [bug description]
    --> wrapper -r debugger -d "@dir/" "bug description"
    --> debugger agent + standard prompt

/kimi-verify [description]
    --> wrapper -t verify --diff "description"
    --> verify template + git diff injection

/kimi-audit [type] [dir]
    --> wrapper -r {type} -d "@dir/" "audit"
    --> security/auditor role + standard prompt
```

### Installation Flow

```
User runs: ./install.sh
    |
    v
Prerequisite check:
    |-- kimi CLI installed? (command -v kimi)
    |-- git installed? (optional, for --diff)
    |
    v
Select install type:
    |-- 1) Global: target = ~/.claude/
    |-- 2) Project: target = ./
    |-- 3) Custom: target = user-specified
    |
    v
Copy files:
    |-- skills/kimi.agent.wrapper.sh --> target/skills/
    |-- skills/kimi.ps1 --> target/skills/
    |-- .kimi/agents/*.yaml --> target/.kimi/agents/
    |-- .kimi/agents/prompts/*.md --> target/.kimi/agents/prompts/
    |-- .kimi/templates/*.md --> target/.kimi/templates/
    |-- KimiContext.md --> target/
    |-- .claude/commands/kimi/*.md --> target/.claude/commands/kimi/ (or target/commands/kimi/ for global)
    |-- .claude/skills/kimi-research/SKILL.md --> target skill location
    |
    v
Verify installation:
    |-- kimi.agent.wrapper.sh --dry-run "test"
    |
    v
Print usage instructions
```

## Anti-Patterns

### Anti-Pattern 1: Monolithic Prompt Construction in Wrapper

**What people do:** Build the entire system prompt in bash by concatenating role text, output format instructions, context, template, and user query into one giant string (the Gemini wrapper approach).

**Why it is wrong:** This defeats the purpose of Kimi's agent system. The wrapper becomes the bottleneck for every feature addition. Role behavior cannot be tested independently. The bash string manipulation becomes fragile at scale.

**Do this instead:** Put role personality and output format in the agent YAML's system prompt markdown file. The wrapper only handles template + context + diff + user query. Kimi applies the system prompt at the model level.

### Anti-Pattern 2: Reimplementing Kimi Features in the Wrapper

**What people do:** Add caching, retry logic, session management, model fallback, token estimation, and structured output formatting to the wrapper script.

**Why it is wrong:** Kimi CLI handles session management (`--continue`, `--session`), model selection (`--model`), auto-approval (`--yolo` / `--quiet`), and output formatting natively. Reimplementing these in bash creates maintenance burden and version skew.

**Do this instead:** Pass Kimi flags through. If the user wants a specific model, pass `--model` to kimi. If they want thinking mode, pass `--thinking`. The wrapper should not second-guess Kimi's native capabilities.

### Anti-Pattern 3: Hardcoded Templates in Bash

**What people do:** Define templates as heredocs inside the bash script (the Gemini wrapper has all templates in `get_template()` function as inline strings).

**Why it is wrong:** Changing a template requires editing the wrapper script. Users cannot add custom templates without modifying the wrapper. Template content mixed with bash logic is hard to read.

**Do this instead:** Templates are external markdown files in `.kimi/templates/`. The wrapper reads them by filename. Custom templates are added by dropping a `.md` file in the directory.

### Anti-Pattern 4: Output Format Injection at Wrapper Level

**What people do:** Append a `ROLE_OUTPUT_FORMAT` string to every role's prompt (the Gemini wrapper concatenates a standard format block after every role).

**Why it is wrong:** The output format instruction should be part of the system prompt, not injected by the wrapper. It creates a hidden coupling where changing the format requires editing the wrapper, and the format is invisible when inspecting the role markdown file.

**Do this instead:** Include output format instructions directly in each role's system prompt markdown file. Or create a shared prompt fragment that each role's `.md` file references. The role file should be self-contained.

### Anti-Pattern 5: Dual-Mode Invocation (Bash + PowerShell Logic)

**What people do:** Duplicate logic between the bash wrapper and PowerShell shim, or add PowerShell-specific argument handling.

**Why it is wrong:** Two implementations to maintain. Bugs appear in one but not the other.

**Do this instead:** The PowerShell shim is ONLY a path-resolver and delegator. It finds `bash.exe`, converts Windows paths to Unix paths, and calls the bash wrapper. Zero logic beyond that. The existing `gemini.ps1` (45 lines) gets this right.

## Integration Points

### External Services

| Service | Integration Pattern | Notes |
|---------|---------------------|-------|
| Kimi CLI | Shell invocation via `kimi` command | Requires `uv tool install kimi-cli` or `brew install kimi-cli`. Version 1.7.0+ |
| Git | Shell invocation for `--diff` feature | Optional dependency. Wrapper checks `command -v git` before use |
| Claude Code | Slash commands + SKILL.md + Bash tool | Claude reads command files, invokes wrapper via Bash tool |

### Internal Boundaries

| Boundary | Communication | Notes |
|----------|---------------|-------|
| Slash Command --> Wrapper | Shell invocation with arguments | Command file instructs Claude what flags to use |
| Wrapper --> Kimi CLI | Shell invocation with `--agent-file`, `--quiet`, `-p` | One-shot execution, stdout capture |
| Wrapper --> Agent YAML | File read to resolve path | Wrapper finds the YAML; Kimi reads and interprets it |
| Agent YAML --> System Prompt | `system_prompt_path` field | Kimi resolves relative to YAML file location |
| Wrapper --> Template | File read | Wrapper reads `.md` content and prepends to prompt |
| Wrapper --> Context File | File read | Wrapper reads `KimiContext.md` and prepends to prompt |
| Wrapper --> Git | Shell invocation | For `--diff` flag: `git diff`, `git diff --name-only` |

## Cross-Platform Considerations

### Windows (Git Bash)

| Concern | Approach |
|---------|----------|
| bash availability | PowerShell shim resolves bash path from Git for Windows installation |
| Path separators | shim converts `\` to `/` before passing to bash |
| `kimi` command | Must be on PATH (installed via `uv tool install kimi-cli` or `pip install kimi-cli`) |
| Line endings | Git handles via `.gitattributes` (already present); wrapper uses `set -euo pipefail` |
| `command -v` | Works in Git Bash |
| `mktemp` / temp files | Git Bash provides GNU coreutils |
| Color codes | ANSI colors work in Git Bash and Windows Terminal |

### macOS

| Concern | Approach |
|---------|----------|
| bash version | macOS ships bash 3.x; wrapper must avoid bash 4+ features (associative arrays, `${var,,}`) |
| `stat` command | BSD stat differs from GNU stat; the Gemini wrapper already handles this; new wrapper should not need stat |
| `kimi` command | `brew install kimi-cli` or `uv tool install kimi-cli` |
| `realpath` | Not available on older macOS; use `cd "$(dirname "$0")" && pwd` pattern |

### Linux

| Concern | Approach |
|---------|----------|
| Standard | Bash wrapper works natively |
| `kimi` command | `uv tool install kimi-cli` or system package |

### Key Constraint: bash 3.x Compatibility

The wrapper MUST work with bash 3.2 (macOS default). Avoid:
- Associative arrays (`declare -A`)
- `${var,,}` lowercase expansion
- `|&` pipe-with-stderr
- `[[ $var =~ regex ]]` with stored regex variables
- `readarray` / `mapfile`

## Build Order (Dependency Graph)

Components must be built in this order based on dependencies:

```
Phase 1: Foundation (no dependencies)
    |-- Agent YAML files + system prompt markdown files
    |-- Template markdown files
    |-- KimiContext.md

Phase 2: Core Wrapper (depends on Phase 1)
    |-- kimi.agent.wrapper.sh
    |       Depends on: agent files exist, template files exist, context file pattern
    |       Contains: arg parsing, role resolution, template loading,
    |                 context injection, diff injection, kimi invocation

Phase 3: Claude Code Integration (depends on Phase 2)
    |-- SKILL.md
    |       Depends on: knowing wrapper interface (flags, roles, templates)
    |-- Slash commands (.claude/commands/kimi/*.md)
    |       Depends on: knowing wrapper interface + SKILL.md content

Phase 4: Cross-Platform (depends on Phase 2)
    |-- kimi.ps1 (PowerShell shim)
    |       Depends on: wrapper script location and interface

Phase 5: Distribution (depends on all above)
    |-- install.sh
    |-- uninstall.sh
    |-- README.md
    |-- Documentation
```

**Rationale for this order:**

1. Agent files and templates are pure content with no code dependencies. They can be tested independently by running `kimi --agent-file agents/reviewer.yaml --quiet -p "test"`. Build these first to validate the Kimi CLI interface works as expected.

2. The core wrapper depends on knowing where agent files and templates live. It must be buildable after the file structure is established.

3. Claude Code integration (SKILL.md and slash commands) requires knowing the wrapper's exact interface -- what flags it accepts, what roles are available. These cannot be finalized until the wrapper interface is stable.

4. The PowerShell shim only needs to know the wrapper's filename and location. It is a thin delegator.

5. The installer copies files around. It must know the complete file manifest, so it goes last.

## Scaling Considerations

This is a CLI plugin, not a web service. "Scaling" means supporting more roles, templates, and use patterns.

| Scale | Architecture Adjustments |
|-------|--------------------------|
| 15 roles (current plan) | Flat directory structure works fine. One YAML + one .md per role |
| 50+ roles | Consider role categories in subdirectories: `.kimi/agents/analysis/`, `.kimi/agents/action/`, `.kimi/agents/expert/`. Wrapper resolution would need to search subdirectories |
| Multiple AI backends | The wrapper is Kimi-specific. If supporting both Gemini and Kimi, the repo would need separate wrappers (gemini.agent.wrapper.sh + kimi.agent.wrapper.sh). Do NOT try to make one wrapper support both -- the agent file formats are incompatible |
| Team usage | The `.kimi/` directory can be committed to project repos. Team members get the same roles. Global install handles personal customization |

## Sources

- Kimi CLI official agent docs: [https://moonshotai.github.io/kimi-cli/en/customization/agents.html](https://moonshotai.github.io/kimi-cli/en/customization/agents.html) [HIGH confidence]
- Kimi CLI command reference: [https://www.kimi-cli.com/en/reference/kimi-command.html](https://www.kimi-cli.com/en/reference/kimi-command.html) [HIGH confidence]
- Kimi CLI GitHub: [https://github.com/MoonshotAI/kimi-cli](https://github.com/MoonshotAI/kimi-cli) [HIGH confidence]
- Kimi CLI AGENTS.md: [https://github.com/MoonshotAI/kimi-cli/blob/main/AGENTS.md](https://github.com/MoonshotAI/kimi-cli/blob/main/AGENTS.md) [HIGH confidence]
- Kimi CLI skills docs: [https://moonshotai.github.io/kimi-cli/en/customization/skills.html](https://moonshotai.github.io/kimi-cli/en/customization/skills.html) [HIGH confidence]
- Kimi CLI technical deep dive: [https://llmmultiagents.com/en/blogs/kimi-cli-technical-deep-dive](https://llmmultiagents.com/en/blogs/kimi-cli-technical-deep-dive) [MEDIUM confidence]
- Claude Code slash commands: [https://code.claude.com/docs/en/slash-commands](https://code.claude.com/docs/en/slash-commands) [HIGH confidence]
- Existing Gemini wrapper codebase: `C:\Users\dasbl\Multi-Agent-Workflow\skills\gemini.agent.wrapper.sh` [HIGH confidence - direct analysis]
- Existing codebase architecture: `C:\Users\dasbl\Multi-Agent-Workflow\.planning\codebase\ARCHITECTURE.md` [HIGH confidence - direct analysis]
- PROJECT.md requirements: `C:\Users\dasbl\Multi-Agent-Workflow\.planning\PROJECT.md` [HIGH confidence - project source of truth]

---
*Architecture research for: Claude Code + Kimi CLI wrapper plugin*
*Researched: 2026-02-04*
