# Phase 1: Core Wrapper - Research

**Researched:** 2026-02-04
**Domain:** Bash CLI wrapper script for Kimi CLI invocation
**Confidence:** HIGH

## Summary

This phase builds a bash wrapper script (`kimi.agent.wrapper.sh`) that invokes Kimi CLI with role-based agent file selection, flag pass-through (`-r`, `-m`, `-w`), and startup validation (CLI presence + version check). The primary technology is pure bash scripting targeting cross-platform compatibility (macOS, Linux, Windows via Git Bash). No external dependencies beyond `kimi` CLI itself.

Research confirmed Kimi CLI v1.7.0 (released 2026-02-04) as the current version with well-documented flags: `--quiet` (shortcut for `--print --output-format text --final-message-only`), `--agent-file PATH`, `--model/-m NAME`, `--work-dir/-w PATH`, `--prompt/-p TEXT`, and `--yolo/-y`. The `--quiet` flag is the correct mode for non-interactive wrapper usage, as it produces clean text output with no interactive chrome. The existing Gemini wrapper (1060 lines) provides proven patterns for argument parsing, role resolution, and cross-platform OS detection, though the new wrapper should be dramatically simpler (~300 lines) because Kimi CLI handles what the old wrapper did manually.

Key recommendations: Use manual while-case argument parsing (not getopts, which lacks long-option support). Use `command -v` for binary detection (POSIX-compliant, works in Git Bash). Use `--quiet` mode exclusively for non-interactive invocation. Pin minimum version to 1.7.0. Use `kimi --version` for version checking.

**Primary recommendation:** Build a clean ~300-line bash script using manual argument parsing, `command -v` for CLI detection, `kimi --quiet` for invocation, and two-tier agent file resolution with clear error messages.

## Standard Stack

### Core

| Tool | Version | Purpose | Why Standard |
|------|---------|---------|--------------|
| Kimi CLI | >= 1.7.0 | AI agent CLI being wrapped | Target CLI; --quiet mode provides clean non-interactive output |
| Bash | >= 4.0 | Script interpreter | Ships with macOS, Linux, Git Bash on Windows |
| kimi --quiet | v1.7.0+ | Non-interactive invocation mode | Shortcut for --print --output-format text --final-message-only; produces clean stdout |

### Supporting

| Tool | Version | Purpose | When to Use |
|------|---------|---------|-------------|
| command -v | POSIX builtin | Binary detection | Always; replaces `which` for portability |
| kimi --version | CLI builtin | Version string retrieval | Startup validation check |
| uname | POSIX | OS detection | Platform-specific install instructions in error messages |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `--quiet` | `--print --final-message-only` | --quiet is the designed shortcut for exactly this; use it |
| `command -v` | `which` | `which` behaves inconsistently across shells; `command -v` is POSIX |
| Manual arg parsing | `getopts` | getopts cannot handle long options (--quiet, --agent-file); manual loop is required |
| Manual arg parsing | External `getopt` | getopt has portability issues (GNU vs BSD); manual parsing is safer |

**Installation (Kimi CLI):**
```bash
# macOS
brew install kimi-cli
# OR via uv (all platforms)
uv tool install kimi-cli
# OR via pip (all platforms)
pip install kimi-cli
```

## Architecture Patterns

### Recommended Script Structure

```
kimi.agent.wrapper.sh          # ~300 lines, single file
  |
  +-- Constants & Defaults     # Lines ~1-30:  Exit codes, default model, min version
  +-- Utility Functions        # Lines ~31-80: die(), warn(), find_kimi(), check_version(),
  |                            #               resolve_agent(), detect_os()
  +-- Argument Parser          # Lines ~81-160: while-case loop over $@
  +-- Validation               # Lines ~161-200: CLI presence, version check, agent resolution
  +-- Invocation               # Lines ~201-260: Build kimi command, emit header, exec
  +-- Exit Handling            # Lines ~261-300: Propagate exit code
```

### Pattern 1: Strict Mode with Controlled Error Handling

**What:** Use `set -euo pipefail` for safety, but handle known-failure paths explicitly.
**When to use:** Always in this wrapper.
**Example:**
```bash
#!/usr/bin/env bash
set -euo pipefail

# For commands that may legitimately fail, use || true or explicit checks
KIMI_BIN="${KIMI_PATH:-$(command -v kimi 2>/dev/null || true)}"
if [[ -z "$KIMI_BIN" ]]; then
    die "kimi CLI not found" "$EXIT_CLI_NOT_FOUND"
fi
```

### Pattern 2: Two-Tier Agent File Resolution

**What:** Check project-local `.kimi/agents/<role>.yaml` first, then global install location.
**When to use:** Every invocation with `-r <role>`.
**Example:**
```bash
resolve_agent() {
    local role="$1"
    local project_agent=".kimi/agents/${role}.yaml"
    local global_agent="${SCRIPT_DIR}/../.kimi/agents/${role}.yaml"

    if [[ -f "$project_agent" ]]; then
        echo "$project_agent"
    elif [[ -f "$global_agent" ]]; then
        echo "$global_agent"
    else
        return 1
    fi
}
```

### Pattern 3: Machine-Parseable Header on stderr

**What:** Emit a single metadata line to stderr before Kimi's output streams to stdout.
**When to use:** Every invocation.
**Example:**
```bash
# Format: [kimi:<role>:<model>] -- easy to regex for Phase 5
# Sent to stderr so stdout is pure Kimi output
echo "[kimi:${ROLE:-none}:${MODEL}]" >&2
```

### Pattern 4: Manual Argument Parsing with While-Case

**What:** Parse both short and long options using a while loop + case statement.
**When to use:** This is the ONLY argument parsing pattern for this wrapper.
**Example:**
```bash
# Source: Gemini wrapper pattern (verified working cross-platform)
while [[ $# -gt 0 ]]; do
    case "$1" in
        -r|--role)
            ROLE="$2"
            shift 2
            ;;
        -m|--model)
            MODEL="$2"
            shift 2
            ;;
        -w|--work-dir)
            WORK_DIR="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        -*)
            # Discretion: pass unknown flags through to kimi
            PASSTHROUGH_ARGS+=("$1")
            if [[ -n "${2:-}" && ! "$2" =~ ^- ]]; then
                PASSTHROUGH_ARGS+=("$2")
                shift
            fi
            shift
            ;;
        *)
            PROMPT="$1"
            shift
            ;;
    esac
done
```

### Pattern 5: Platform-Specific Error Messages

**What:** Detect OS and provide tailored install instructions.
**When to use:** When kimi CLI is not found.
**Example:**
```bash
detect_os() {
    case "$(uname -s)" in
        Darwin*)  echo "macos" ;;
        Linux*)   echo "linux" ;;
        MINGW*|MSYS*|CYGWIN*) echo "windows" ;;
        *)        echo "unknown" ;;
    esac
}

show_install_instructions() {
    local os
    os=$(detect_os)
    echo "Error: kimi CLI not found." >&2
    echo "" >&2
    echo "Install kimi-cli:" >&2
    case "$os" in
        macos)
            echo "  brew install kimi-cli" >&2
            echo "  # or: uv tool install kimi-cli" >&2
            ;;
        linux)
            echo "  uv tool install kimi-cli" >&2
            echo "  # or: pip install kimi-cli" >&2
            ;;
        windows)
            echo "  uv tool install kimi-cli" >&2
            echo "  # or: pip install kimi-cli" >&2
            echo "  # Tip: Set KIMI_PATH env var if PATH is unreliable" >&2
            ;;
    esac
    echo "" >&2
    echo "Requires Python >= 3.12 (3.13 recommended)" >&2
}
```

### Anti-Patterns to Avoid

- **Color output in error messages:** Decision locked -- plain text only, no ANSI escape codes. Maximum compatibility with pipes, CI, log capture.
- **Using `eval` to build commands:** Security risk and debugging nightmare. Build commands using arrays and `"${cmd[@]}"` expansion instead.
- **Using `which` instead of `command -v`:** `which` behavior varies across shells and platforms. `command -v` is POSIX and reliable.
- **Using `getopts` for long options:** getopts only handles single-character flags. The wrapper needs `--role`, `--model`, `--work-dir`.
- **Hardcoding kimi path:** Always use `KIMI_PATH` env var with `command -v` fallback. Windows PATH is unreliable after updates.
- **Mixing stdout and stderr carelessly:** Kimi output goes to stdout. All wrapper messages (header, errors, warnings) go to stderr. This keeps stdout clean for piping.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Non-interactive Kimi output | Custom output filtering/parsing | `kimi --quiet` flag | --quiet = --print --output-format text --final-message-only; this is the designed mode |
| Agent file loading | Custom YAML parsing | `kimi --agent-file` flag | Kimi resolves system_prompt_path relative to YAML location natively |
| Auto-approval | Custom stdin piping | `--quiet` implies `--yolo` | --quiet automatically enables auto-approval |
| Model selection | Config file parsing | `kimi --model NAME` flag | Direct CLI pass-through is simpler |
| Working directory | `cd` before invocation | `kimi --work-dir PATH` flag | Kimi handles this natively |
| Session management | Custom state files | Kimi's native `--session`/`--continue` | Out of scope for Phase 1; Kimi handles natively |
| Version parsing | Custom regex against help text | `kimi --version` flag | Standard flag that outputs version string |

**Key insight:** The entire value of this wrapper is thin orchestration (role resolution + validation + flag assembly). Kimi CLI handles all the heavy lifting. The wrapper should be ~300 lines, not ~1060 like the Gemini version, because most Gemini wrapper features were compensating for Gemini CLI's lack of native agent/role support.

## Common Pitfalls

### Pitfall 1: Word Splitting in Command Construction

**What goes wrong:** Building the kimi command as a string causes word-splitting bugs, especially with prompts containing spaces or special characters.
**Why it happens:** Using `eval "$CMD"` or `$CMD` instead of array expansion.
**How to avoid:** Build commands as bash arrays and invoke with `"${cmd[@]}"`.
**Warning signs:** Prompts with spaces, quotes, or newlines break.

```bash
# WRONG: string-based command building
CMD="kimi --quiet -p \"$PROMPT\""
eval "$CMD"

# RIGHT: array-based command building
cmd=("$KIMI_BIN" "--quiet")
[[ -n "$AGENT_FILE" ]] && cmd+=("--agent-file" "$AGENT_FILE")
[[ -n "$MODEL" ]] && cmd+=("--model" "$MODEL")
cmd+=("-p" "$PROMPT")
"${cmd[@]}"
```

### Pitfall 2: Exit Code Swallowing with set -e

**What goes wrong:** `set -e` causes the script to exit before it can handle Kimi's non-zero exit code.
**Why it happens:** `set -e` exits on any non-zero return, including intentional non-zero from Kimi.
**How to avoid:** Capture Kimi's exit code explicitly.
**Warning signs:** Wrapper always exits 0 or always exits on Kimi failure without cleanup.

```bash
# Capture exit code without triggering set -e
"${cmd[@]}" || kimi_exit=$?
kimi_exit=${kimi_exit:-0}
exit "$kimi_exit"
```

### Pitfall 3: KIMI_PATH with Spaces on Windows

**What goes wrong:** `KIMI_PATH="/c/Program Files/..."` breaks without quoting.
**Why it happens:** Windows paths frequently contain spaces (Program Files).
**How to avoid:** Always double-quote `$KIMI_PATH` and `$KIMI_BIN` everywhere.
**Warning signs:** Works on Linux/macOS but fails on Windows.

### Pitfall 4: Version String Parsing Fragility

**What goes wrong:** Version check breaks when kimi changes its `--version` output format.
**Why it happens:** Parsing version strings with exact regex is brittle.
**How to avoid:** Extract only the version number portion, compare major.minor.patch numerically. Fall back to warning (not error) if parsing fails.
**Warning signs:** Version check fails on new kimi releases.

```bash
# Robust version extraction: look for first N.N.N pattern
KIMI_VERSION=$("$KIMI_BIN" --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
if [[ -z "$KIMI_VERSION" ]]; then
    warn "Could not determine kimi CLI version"
    # Continue anyway -- version check is a warning, not a blocker
fi
```

### Pitfall 5: Agent File Path Resolution Across Platforms

**What goes wrong:** Relative paths to agent files work differently on Windows Git Bash vs native Linux/macOS.
**Why it happens:** Git Bash translates paths; `SCRIPT_DIR` detection varies.
**How to avoid:** Use `$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)` for SCRIPT_DIR. Use `realpath` or `readlink -f` with fallback for resolving paths.
**Warning signs:** Agent file found on macOS but not in Git Bash (or vice versa).

```bash
# Cross-platform SCRIPT_DIR
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Cross-platform realpath fallback
resolve_path() {
    if command -v realpath &>/dev/null; then
        realpath "$1"
    elif command -v readlink &>/dev/null; then
        readlink -f "$1" 2>/dev/null || echo "$1"
    else
        echo "$1"
    fi
}
```

### Pitfall 6: stdin Detection for Piped Input

**What goes wrong:** Script hangs waiting for input when no prompt is provided and stdin is not a TTY.
**Why it happens:** Not checking whether stdin has data before trying to read it.
**How to avoid:** Use `[[ ! -t 0 ]]` to detect piped stdin, and only read if data is available.
**Warning signs:** Script hangs in CI pipelines or when called without arguments.

```bash
# Read prompt from stdin if piped
if [[ -z "$PROMPT" && ! -t 0 ]]; then
    PROMPT=$(cat)
fi
```

## Code Examples

### Complete Kimi CLI Invocation Pattern

```bash
# Source: Kimi CLI official docs (kimi-command reference)
# Verified flags: --quiet, --agent-file, --model, --work-dir, --prompt

KIMI_BIN="${KIMI_PATH:-$(command -v kimi 2>/dev/null || true)}"

cmd=("$KIMI_BIN" "--quiet")

# Add agent file if role was specified and resolved
if [[ -n "${AGENT_FILE:-}" ]]; then
    cmd+=("--agent-file" "$AGENT_FILE")
fi

# Add model (default or user-specified)
cmd+=("--model" "$MODEL")

# Add working directory if specified
if [[ -n "${WORK_DIR:-}" ]]; then
    cmd+=("--work-dir" "$WORK_DIR")
fi

# Add any passthrough args
if [[ ${#PASSTHROUGH_ARGS[@]} -gt 0 ]]; then
    cmd+=("${PASSTHROUGH_ARGS[@]}")
fi

# Add the prompt
cmd+=("--prompt" "$PROMPT")

# Emit machine-parseable header to stderr
echo "[kimi:${ROLE:-none}:${MODEL}]" >&2

# Execute and propagate exit code
"${cmd[@]}" || kimi_exit=$?
exit "${kimi_exit:-0}"
```

### Version Comparison Function

```bash
# Compare two semantic version strings
# Returns 0 if $1 >= $2, 1 otherwise
version_gte() {
    local v1="$1" v2="$2"
    # Sort versions and check if v1 comes last (or equals v2)
    local sorted
    sorted=$(printf '%s\n%s' "$v1" "$v2" | sort -V | tail -1)
    [[ "$sorted" == "$v1" ]]
}

MIN_VERSION="1.7.0"
CURRENT_VERSION=$("$KIMI_BIN" --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)

if [[ -n "$CURRENT_VERSION" ]] && ! version_gte "$CURRENT_VERSION" "$MIN_VERSION"; then
    warn "kimi CLI $CURRENT_VERSION is below minimum $MIN_VERSION -- some features may not work"
fi
```

**Note:** `sort -V` (version sort) is available in GNU coreutils (Linux), macOS 10.14+ (via Homebrew or Xcode tools), and Git Bash (ships with GNU sort). If cross-platform issues arise, fall back to numeric comparison of major.minor.patch components.

### Exit Code Scheme

```bash
# Wrapper-specific exit codes (high numbers to avoid collision with kimi's own codes)
readonly EXIT_SUCCESS=0
readonly EXIT_CLI_NOT_FOUND=10
readonly EXIT_BAD_ARGS=11
readonly EXIT_ROLE_NOT_FOUND=12
readonly EXIT_NO_PROMPT=13
# Exit codes 1-9 are reserved for kimi CLI's own exit codes (propagated directly)
```

### Role Not Found with Available List

```bash
# Discretion recommendation: show available roles when requested role not found
list_available_roles() {
    local roles=()
    # Check project-local agents
    if [[ -d ".kimi/agents" ]]; then
        for f in .kimi/agents/*.yaml; do
            [[ -f "$f" ]] && roles+=("$(basename "$f" .yaml)")
        done
    fi
    # Check global agents
    if [[ -d "${SCRIPT_DIR}/../.kimi/agents" ]]; then
        for f in "${SCRIPT_DIR}/../.kimi/agents"/*.yaml; do
            [[ -f "$f" ]] && roles+=("$(basename "$f" .yaml)")
        done
    fi
    # Deduplicate and sort
    printf '%s\n' "${roles[@]}" | sort -u | tr '\n' ', ' | sed 's/,$/\n/'
}

die_role_not_found() {
    local role="$1"
    echo "Error: role '$role' not found." >&2
    local available
    available=$(list_available_roles)
    if [[ -n "$available" ]]; then
        echo "Available roles: $available" >&2
    else
        echo "No agent files found in .kimi/agents/ or ${SCRIPT_DIR}/../.kimi/agents/" >&2
    fi
    exit "$EXIT_ROLE_NOT_FOUND"
}
```

## State of the Art

| Old Approach (Gemini Wrapper) | Current Approach (Kimi Wrapper) | Why Changed | Impact |
|-------------------------------|--------------------------------|-------------|--------|
| Prompt injection for roles | `--agent-file` native flag | Kimi CLI has native agent system | Eliminates ~200 lines of role prompt construction |
| `eval "$CMD" '"$PROMPT"'` | Array-based `"${cmd[@]}"` | Security and correctness | No word-splitting or injection bugs |
| ANSI color output | Plain text only | Decision: maximum pipe/CI compatibility | Simpler code, broader compatibility |
| 1060 lines with caching, batching, retries | ~300 lines with core invocation only | Kimi handles sessions, retries natively | 70% less code to maintain |
| `gemini -m model` | `kimi --quiet --model NAME -p "prompt"` | Different CLI, different flags | Must use kimi's exact flag names |
| Role text embedded in script | Role files in `.kimi/agents/*.yaml` | Externalized, maintainable, Kimi-native | Phase 2 builds roles independently |

**Deprecated/outdated from Gemini wrapper:**
- Response caching: Kimi has `--session`/`--continue` natively
- Batch mode: Low value, adds complexity
- Token estimation: Not reliable across models
- Smart context grep: Kimi reads working directory natively
- jq dependency: Not needed; no JSON handling in wrapper
- Model fallback logic: Kimi handles provider errors internally
- Color output: Kimi output goes to Claude Code, not human eyes

## Discretion Recommendations

The following areas were marked as "Claude's Discretion" in CONTEXT.md. Here are research-informed recommendations.

### Output Streams & Exit Codes

**Recommendation:** All wrapper-generated output (header, errors, warnings) goes to **stderr**. Only Kimi's actual output goes to **stdout**. This keeps stdout clean for piping (`kimi.agent.wrapper.sh -r reviewer "code" | other-tool`).

**Exit code scheme:**
- `0`: Success (Kimi ran and exited 0)
- `1-9`: Reserved -- propagate Kimi's exit code directly
- `10`: Kimi CLI not found
- `11`: Bad arguments (missing required arg, invalid flag)
- `12`: Role not found
- `13`: No prompt provided

### Resolution UX (Role Not Found)

**Recommendation:** When a role is not found, show an error with the list of available roles from both project-local and global directories. Do NOT implement fuzzy matching in Phase 1 (complexity not justified yet). If project-local overrides global, do it **silently** -- this is expected behavior (like `.gitignore` overriding global gitignore), and verbose mode in Phase 4 will surface it.

### Flag Handling (Unknown Flags)

**Recommendation:** Pass unknown flags through to Kimi CLI. This is future-compatible -- if Kimi adds new flags, the wrapper doesn't need updating. Users who mistype flags will get Kimi's own error message, which is informative. The only flags the wrapper consumes are `-r`, `-m`, `-w`, and `-h`.

### Prompt from stdin

**Recommendation:** Support piped stdin as prompt source. Check `[[ ! -t 0 ]]` to detect piped input. This enables `echo "review this" | kimi.agent.wrapper.sh -r reviewer` and is a common Unix pattern. If both positional arg and stdin are provided, positional arg takes precedence.

## Open Questions

1. **Exact `kimi --version` output format**
   - What we know: `kimi --version` exists (confirmed in official docs, flag `-V` is alias)
   - What's unclear: Exact output string format (e.g., "kimi 1.7.0" vs "kimi-cli 1.7.0" vs just "1.7.0")
   - Recommendation: Use `grep -oE '[0-9]+\.[0-9]+\.[0-9]+'` to extract version number regardless of surrounding text. If extraction fails, emit warning and continue.

2. **Default model name string**
   - What we know: Default model in kimi-cli config is `kimi-for-coding`. K2.5 models are named `kimi-k2.5`, `kimi-k2-thinking-turbo`, etc. via API providers.
   - What's unclear: Whether `kimi-for-coding` resolves to K2.5 or if we should use an explicit model name like `kimi-k2.5`.
   - Recommendation: Use `kimi-for-coding` as the wrapper default model (matches kimi-cli's own default). This way the wrapper inherits whatever model the user's kimi config maps to. If user wants a specific model, they use `-m kimi-k2.5` explicitly.

3. **`sort -V` availability on all platforms**
   - What we know: Available in GNU coreutils (Linux), macOS 10.14+, Git Bash for Windows
   - What's unclear: Whether very old macOS systems or minimal Linux containers lack it
   - Recommendation: Use `sort -V` with a fallback to manual numeric comparison. For Phase 1, `sort -V` is sufficient -- edge cases can be addressed if reported.

4. **`--work-dir` vs `-w` flag name**
   - What we know: Official docs confirm `--work-dir / -w PATH` as the exact flag specification
   - What's unclear: Whether the PROJECT.md reference to `-w` is based on verified docs or assumed
   - Recommendation: Confirmed. The flag is `--work-dir` with `-w` as the short form. Use `-w` in wrapper's argument parser and pass through as `--work-dir` to kimi.

## Sources

### Primary (HIGH confidence)

- [Kimi CLI official command reference](https://www.kimi-cli.com/en/reference/kimi-command.html) -- Complete flag list including --quiet, --agent-file, --model, --work-dir, --prompt, --yolo, --version, --thinking, --session, --continue, --output-format, --final-message-only
- [Kimi CLI agents documentation](https://moonshotai.github.io/kimi-cli/en/customization/agents.html) -- Agent YAML format: version, extend, name, system_prompt_path, tools, exclude_tools, subagents, system_prompt_args
- [Kimi CLI config documentation](https://moonshotai.github.io/kimi-cli/en/configuration/config-files.html) -- Config fields: default_model, providers, models, loop_control
- [PyPI kimi-cli](https://pypi.org/project/kimi-cli/) -- Version 1.7.0, Python >= 3.12
- [Homebrew kimi-cli](https://formulae.brew.sh/formula/kimi-cli) -- Version 1.7.0, brew install kimi-cli
- [DeepWiki kimi-cli command reference](https://deepwiki.com/MoonshotAI/kimi-cli/2.3-command-line-options-reference) -- Comprehensive flag listing with descriptions

### Secondary (MEDIUM confidence)

- [GitHub MoonshotAI/kimi-cli](https://github.com/MoonshotAI/kimi-cli) -- Repository, releases, v1.7.0 release notes
- [Kimi CLI providers docs](https://moonshotai.github.io/kimi-cli/en/configuration/providers.html) -- Model configuration structure
- Existing Gemini wrapper (`skills/gemini.agent.wrapper.sh`) -- Proven patterns for argument parsing, role resolution, OS detection

### Tertiary (LOW confidence)

- `kimi --version` output format -- Not directly observed; version extraction regex is a best-guess pattern
- `kimi-for-coding` as default model name -- Found in search results referencing config, not directly verified in current v1.7.0

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- Official docs confirm all flags, versions verified on PyPI and Homebrew
- Architecture: HIGH -- Patterns derived from working Gemini wrapper + confirmed kimi CLI flags
- Pitfalls: HIGH -- Cross-platform bash issues are well-documented; version parsing and path issues are known
- Discretion items: MEDIUM -- Recommendations are informed but involve design choices that should be validated in practice

**Research date:** 2026-02-04
**Valid until:** 2026-03-06 (30 days -- kimi-cli is actively developed, re-verify flags before Phase 3+)
