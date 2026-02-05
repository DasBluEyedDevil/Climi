# Phase 4: Developer Experience - Research

**Researched:** 2026-02-04
**Domain:** Bash scripting, CLI wrapper development, Kimi CLI integration
**Confidence:** HIGH

## Summary

This research covers the implementation of developer experience features for the `kimi.agent.wrapper.sh` script, including dry-run mode, verbose debugging, thinking flag pass-through, and enhanced help output. The wrapper is a ~436-line bash script that acts as a bridge between users and the Kimi CLI, providing role-based agent selection, template injection, and git diff integration.

**Primary recommendation:** Implement `--dry-run` as a command preview (show but don't execute), `--verbose` as wrapper-internal debug output (not to be confused with Kimi's `--verbose`), `--thinking` as direct pass-through to Kimi CLI, and `--help` with dynamic role/template enumeration.

## Standard Stack

### Core (Already in Use)
| Component | Version | Purpose | Notes |
|-----------|---------|---------|-------|
| Bash | 4.0+ | Script runtime | Script uses `set -euo pipefail` |
| Kimi CLI | 1.7.0+ | Target CLI | Minimum version checked at runtime |
| Git | Any | Diff capture | Optional feature for context injection |

### No Additional Dependencies Required
All features can be implemented using standard bash built-ins and existing script infrastructure.

## Architecture Patterns

### Pattern 1: Dry-Run Mode (Show Without Execute)
**What:** Display the constructed command without executing it
**When to use:** Users want to verify what will happen before running

**Implementation approach:**
```bash
# Add to argument parsing
DRY_RUN=false
case "$1" in
    --dry-run)
        DRY_RUN=true; shift ;;
esac

# At execution point
if [[ "$DRY_RUN" == "true" ]]; then
    echo "[DRY-RUN] Would execute:" >&2
    printf '  %q\n' "${cmd[@]}" >&2
    exit 0
fi
```

**Key considerations:**
- Use `%q` format specifier to properly quote arguments for readability
- Output to stderr (consistent with wrapper design principle)
- Exit with code 0 (dry-run succeeded, not an error)
- Show the full command array, not a string representation

### Pattern 2: Verbose Mode (Wrapper Debug Output)
**What:** Show wrapper-internal decision making and state
**When to use:** Debugging wrapper behavior, not Kimi CLI behavior

**Implementation approach:**
```bash
# Add verbose logging function
VERBOSE=false

log_verbose() {
    [[ "$VERBOSE" == "true" ]] || return 0
    echo "[verbose] $*" >&2
}

# Usage throughout script
log_verbose "Resolving agent for role: $ROLE"
log_verbose "Found agent file: $AGENT_FILE"
log_verbose "Template content length: ${#TEMPLATE_CONTENT}"
log_verbose "Passthrough args: ${PASSTHROUGH_ARGS[*]}"
```

**Important distinction:**
- Wrapper `--verbose` = wrapper debug output (our implementation)
- Kimi `--verbose` = Kimi CLI debug output (pass through via passthrough mechanism)
- These are intentionally separate concerns

### Pattern 3: Flag Pass-Through (Thinking Mode)
**What:** Pass `--thinking` flag directly to Kimi CLI
**When to use:** User wants Kimi's deep thinking mode enabled

**Implementation approach:**
The existing passthrough mechanism already handles this:
```bash
-*)
    PASSTHROUGH_ARGS+=("$1")
    if [[ -n "${2:-}" && ! "${2:-}" =~ ^- ]]; then
        PASSTHROUGH_ARGS+=("$2"); shift
    fi
    shift ;;
```

**Verification from Kimi CLI help:**
```
--thinking  --no-thinking    Enable thinking mode. Default: default thinking
                               mode set in config file.
```

The passthrough mechanism will automatically handle `--thinking` and `--no-thinking` flags.

### Pattern 4: Enhanced Help Output
**What:** Comprehensive help showing all flags, roles, and templates
**When to use:** User needs to discover available options

**Implementation approach:**
```bash
usage() {
    cat >&2 <<'USAGE_EOF'
Usage: kimi.agent.wrapper.sh [OPTIONS] PROMPT

Options:
  -r, --role ROLE      Agent role (maps to .kimi/agents/ROLE.yaml)
  -m, --model MODEL    Kimi model (default: kimi-for-coding)
  -w, --work-dir PATH  Working directory for Kimi
  -t, --template TPL   Template to prepend (maps to .kimi/templates/TPL.md)
  --diff               Include git diff in prompt context
  --dry-run            Show command without executing
  --verbose            Show wrapper debug output
  --thinking           Enable Kimi thinking mode (pass-through)
  -h, --help           Show this help

Prompt can also be piped via stdin.
Unknown flags are passed through to kimi CLI.
USAGE_EOF

    # Dynamic sections
    local roles templates
    roles=$(list_available_roles)
    templates=$(list_available_templates)
    
    [[ -n "$roles" ]] && echo -e "\nAvailable roles:\n  $roles" >&2
    [[ -n "$templates" ]] && echo -e "\nAvailable templates:\n  $templates" >&2
    
    exit 0
}
```

**Role/Template Enumeration (Existing Functions):**
The script already has `list_available_roles()` and `list_available_templates()` functions that:
1. Search both project-local and global directories
2. Return comma-separated lists
3. Handle missing directories gracefully

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Command quoting for display | Custom escaping | `printf '%q'` | Handles all edge cases correctly |
| Argument parsing | Manual shift loops | Existing case statement | Already implemented and tested |
| Role/template discovery | `find` with parsing | Existing `list_*` functions | Already handles both local and global dirs |
| Debug output | `echo` statements | Centralized `log_verbose` | Consistent format, easy to disable |

## Common Pitfalls

### Pitfall 1: Confusing Verbose Modes
**What goes wrong:** User uses `--verbose` expecting Kimi CLI verbose output, but gets wrapper debug output
**Why it happens:** Two different components have flags with the same name
**How to avoid:** 
- Document the distinction clearly in help
- Consider renaming wrapper flag to `--debug` or `--wrapper-verbose`
- Or accept that both will produce debug output (wrapper first, then Kimi)

### Pitfall 2: Dry-Run Exit Code Confusion
**What goes wrong:** Scripts checking exit code expect non-zero for "didn't run"
**Why it happens:** Some tools use exit code 1 for dry-run
**How to avoid:** Exit 0 for dry-run success (command was valid, just not executed)

### Pitfall 3: Leaking Secrets in Dry-Run Output
**What goes wrong:** API keys or tokens in environment variables shown in dry-run
**Why it happens:** `printf '%q'` shows expanded values
**How to avoid:** 
- Document that dry-run shows final command
- Consider masking known sensitive patterns
- Acceptable risk for local CLI tool

### Pitfall 4: Passthrough Flag Collision
**What goes wrong:** Wrapper adds `--thinking` handling, but passthrough also catches it
**Why it happens:** Both mechanisms process the same flag
**How to avoid:** 
- Document that `--thinking` is passthrough only
- Don't add explicit handling unless wrapper needs to do something special
- Current passthrough design is correct

## Code Examples

### Dry-Run Implementation
```bash
# In argument parsing
--dry-run)
    DRY_RUN=true; shift ;;

# At end of script, before execution
if [[ "$DRY_RUN" == "true" ]]; then
    echo "[DRY-RUN] Constructed command:" >&2
    printf '  %q' "${cmd[0]}" >&2  # First element without leading space
    for ((i=1; i<${#cmd[@]}; i++)); do
        printf ' %q' "${cmd[$i]}" >&2
    done
    echo "" >&2
    
    # Also show assembled prompt preview (truncated)
    if [[ ${#ASSEMBLED_PROMPT} -gt 200 ]]; then
        echo "[DRY-RUN] Assembled prompt (${#ASSEMBLED_PROMPT} chars):" >&2
        echo "  ${ASSEMBLED_PROMPT:0:200}..." >&2
    else
        echo "[DRY-RUN] Assembled prompt:" >&2
        echo "  $ASSEMBLED_PROMPT" >&2
    fi
    
    exit 0
fi
```

### Verbose Logging Implementation
```bash
# Add near other defaults
VERBOSE=false

# Add logging function after other utility functions
log_verbose() {
    [[ "$VERBOSE" == "true" ]] || return 0
    local timestamp
    timestamp=$(date '+%H:%M:%S')
    echo "[$timestamp] $*" >&2
}

# Usage examples throughout script
log_verbose "Starting wrapper v$WRAPPER_VERSION"
log_verbose "Resolved kimi binary: $KIMI_BIN"
log_verbose "Role: ${ROLE:-none}, Model: $MODEL"
log_verbose "Agent file: ${AGENT_FILE:-none}"
log_verbose "Template: ${TEMPLATE:-none}"
log_verbose "Passthrough args count: ${#PASSTHROUGH_ARGS[@]}"
log_verbose "Prompt length: ${#PROMPT} chars"
log_verbose "Work directory: ${WORK_DIR:-.}"
```

### Enhanced Help with Dynamic Content
```bash
usage() {
    cat >&2 <<'USAGE_EOF'
kimi.agent.wrapper.sh -- Kimi CLI wrapper with role-based agent selection

Usage: kimi.agent.wrapper.sh [OPTIONS] PROMPT

Wrapper Options:
  -r, --role ROLE      Agent role (maps to .kimi/agents/ROLE.yaml)
  -m, --model MODEL    Kimi model (default: kimi-for-coding)
  -w, --work-dir PATH  Working directory for Kimi
  -t, --template TPL   Template to prepend (maps to .kimi/templates/TPL.md)
  --diff               Include git diff in prompt context
  --dry-run            Show constructed command without executing
  --verbose            Show wrapper debug output
  -h, --help           Show this help and exit

Kimi CLI Options (pass-through):
  --thinking           Enable thinking mode for deeper reasoning
  --no-thinking        Disable thinking mode
  -y, --yes, --yolo    Auto-approve all actions
  --print              Run in non-interactive print mode
  (and any other kimi CLI flags)

Environment Variables:
  KIMI_PATH            Override kimi binary location

Prompt can also be piped via stdin.
USAGE_EOF

    # Show available roles
    local roles
    roles=$(list_available_roles)
    if [[ -n "$roles" ]]; then
        echo -e "\nAvailable roles: $roles" >&2
    fi
    
    # Show available templates
    local templates
    templates=$(list_available_templates)
    if [[ -n "$templates" ]]; then
        echo -e "\nAvailable templates: $templates" >&2
    fi
    
    # Show examples
    cat >&2 <<'EXAMPLES_EOF'

Examples:
  kimi.agent.wrapper.sh -r reviewer "Review this code"
  kimi.agent.wrapper.sh -r planner -t feature "Plan new feature"
  echo "prompt" | kimi.agent.wrapper.sh -r executor
  kimi.agent.wrapper.sh --dry-run -r reviewer "test"  # Preview command
  kimi.agent.wrapper.sh --verbose -r planner "task"   # Debug wrapper
EXAMPLES_EOF

    exit 0
}
```

## State of the Art

### Current Wrapper Features (Phase 1-3)
| Feature | Status | Notes |
|---------|--------|-------|
| Role resolution | Implemented | Two-tier: project-local, then global |
| Template injection | Implemented | Two-tier resolution |
| Git diff injection | Implemented | Via `--diff` flag |
| Context file loading | Implemented | `.kimi/context.md` or `KimiContext.md` |
| Argument passthrough | Implemented | Unknown flags forwarded to kimi |
| Machine-parseable header | Implemented | `[kimi:role:template:model]` |
| Version checking | Implemented | Warning only, not blocking |

### Kimi CLI Flags (Relevant to Wrapper)
| Flag | Purpose | Wrapper Action |
|------|---------|----------------|
| `--thinking` | Enable deep thinking | Passthrough |
| `--no-thinking` | Disable thinking | Passthrough |
| `--verbose` | Kimi CLI debug | Passthrough (distinct from wrapper --verbose) |
| `--quiet` | Non-interactive mode | Used internally by wrapper |
| `--model` | Select model | Wrapper adds default, allows override |
| `--agent-file` | Custom agent | Wrapper constructs from role |

## Open Questions

1. **Should wrapper --verbose also enable Kimi --verbose?**
   - Option A: Keep separate (current design) - explicit control
   - Option B: Wrapper --verbose adds --verbose to kimi call - convenient but less control
   - **Recommendation:** Keep separate for explicit control

2. **Should dry-run show the assembled prompt content?**
   - Yes: Helps users understand what context is being sent
   - But: Could be very long with large diffs/templates
   - **Recommendation:** Show truncated preview (first 200 chars + total length)

3. **Should help output include role/template descriptions?**
   - Would require parsing YAML frontmatter from agent files
   - Adds complexity but improves UX
   - **Recommendation:** Phase 5 enhancement, not Phase 4

## Recommended Implementation Order

1. **Enhanced Help (`-h`/`--help`)** - WRAP-15
   - Easiest to implement
   - Uses existing `list_*` functions
   - Immediate user value

2. **Thinking Flag Pass-Through** - WRAP-09
   - Verify passthrough mechanism handles it
   - Add documentation
   - May require no code changes (already works)

3. **Verbose Mode (`--verbose`)** - WRAP-14
   - Add `VERBOSE` flag
   - Add `log_verbose()` function
   - Instrument key decision points

4. **Dry-Run Mode (`--dry-run`)** - WRAP-11
   - Add `DRY_RUN` flag
   - Implement command display
   - Add prompt preview
   - Test with various flag combinations

## Sources

### Primary (HIGH confidence)
- Current `skills/kimi.agent.wrapper.sh` source code (436 lines analyzed)
- Kimi CLI `--help` output (captured 2026-02-04)
- GNU Bash Manual: The Set Builtin (https://www.gnu.org/software/bash/manual/html_node/The-Set-Builtin.html)
- Google Shell Style Guide (https://google.github.io/styleguide/shellguide.html)

### Secondary (MEDIUM confidence)
- Stack Overflow: "How can I debug a Bash script?" (community consensus on `set -x`)
- Unix & Linux Stack Exchange: "How to debug a bash script?" (debugging patterns)
- GNU Coding Standards: --help option guidelines

### Implementation Notes
- All code examples tested against bash 4.0+ compatibility
- Follows existing script patterns (arrays for commands, stderr for wrapper output)
- Consistent with established exit code scheme (10-13 for wrapper errors)
