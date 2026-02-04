#!/usr/bin/env bash
# kimi.agent.wrapper.sh -- Kimi CLI wrapper with role-based agent selection
# All wrapper output goes to stderr; only Kimi's output goes to stdout.
# Usage: kimi.agent.wrapper.sh [OPTIONS] PROMPT
#   -r, --role ROLE      Agent role (maps to .kimi/agents/ROLE.yaml)
#   -m, --model MODEL    Kimi model (default: kimi-for-coding)
#   -w, --work-dir PATH  Working directory for Kimi
#   -h, --help           Show this help
# Prompt can also be piped via stdin.

set -euo pipefail

# -- Constants ---------------------------------------------------------------
WRAPPER_VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Exit codes: wrapper-specific (10+), kimi's own codes (1-9) propagated
readonly EXIT_SUCCESS=0
readonly EXIT_CLI_NOT_FOUND=10
readonly EXIT_BAD_ARGS=11
readonly EXIT_ROLE_NOT_FOUND=12
readonly EXIT_NO_PROMPT=13

# -- Defaults ----------------------------------------------------------------
DEFAULT_MODEL="kimi-for-coding"
MIN_VERSION="1.7.0"
ROLE=""
MODEL="$DEFAULT_MODEL"
WORK_DIR=""
PROMPT=""
AGENT_FILE=""
PASSTHROUGH_ARGS=()

# -- Utility functions -------------------------------------------------------

die() { echo "Error: $1" >&2; exit "${2:-1}"; }
warn() { echo "Warning: $1" >&2; }

# Detect OS: returns "macos", "linux", "windows", or "unknown"
detect_os() {
    case "$(uname -s)" in
        Darwin*)            echo "macos" ;;
        Linux*)             echo "linux" ;;
        MINGW*|MSYS*|CYGWIN*) echo "windows" ;;
        *)                  echo "unknown" ;;
    esac
}

# Platform-specific install instructions (stderr)
show_install_instructions() {
    local os
    os=$(detect_os)
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
            echo "" >&2
            echo "  Tip: Set KIMI_PATH env var if PATH is unreliable after updates" >&2
            ;;
        *)
            echo "  uv tool install kimi-cli" >&2
            echo "  # or: pip install kimi-cli" >&2
            ;;
    esac
    echo "" >&2
    echo "Requires Python >= 3.12 (3.13 recommended)" >&2
}

# Resolve kimi binary: KIMI_PATH env var first, then PATH lookup
find_kimi() {
    local kimi_bin=""
    # Check KIMI_PATH env var first (addresses Windows PATH loss)
    if [[ -n "${KIMI_PATH:-}" ]]; then
        if [[ -x "$KIMI_PATH" ]]; then
            echo "$KIMI_PATH"
            return 0
        else
            warn "KIMI_PATH is set to '$KIMI_PATH' but is not executable"
        fi
    fi
    # Fall back to PATH lookup
    kimi_bin=$(command -v kimi 2>/dev/null || true)
    if [[ -n "$kimi_bin" ]]; then
        echo "$kimi_bin"
        return 0
    fi
    # Not found
    echo "Error: kimi CLI not found." >&2
    show_install_instructions
    exit "$EXIT_CLI_NOT_FOUND"
}

# Compare two semver strings: returns 0 if $1 >= $2
version_gte() {
    local v1="$1" v2="$2"
    if [[ "$v1" == "$v2" ]]; then return 0; fi
    local highest
    highest=$(printf '%s\n%s' "$v1" "$v2" | sort -V | tail -1)
    [[ "$highest" == "$v1" ]]
}

# Validate kimi CLI version (warning only, not a hard block)
check_version() {
    local version_output="" kimi_version=""
    version_output=$("$KIMI_BIN" --version 2>/dev/null || true)
    kimi_version=$(echo "$version_output" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || true)
    if [[ -z "$kimi_version" ]]; then
        warn "Could not determine kimi CLI version"
        return 0
    fi
    if ! version_gte "$kimi_version" "$MIN_VERSION"; then
        warn "kimi CLI $kimi_version is below minimum $MIN_VERSION -- some features may not work"
    fi
    return 0
}

# Two-tier agent file resolution: project-local first, then global
resolve_agent() {
    local role="$1"
    local work="${WORK_DIR:-.}"
    local project_agent="${work}/.kimi/agents/${role}.yaml"
    local global_agent="${SCRIPT_DIR}/../.kimi/agents/${role}.yaml"
    if [[ -f "$project_agent" ]]; then
        echo "$project_agent"
        return 0
    elif [[ -f "$global_agent" ]]; then
        echo "$global_agent"
        return 0
    fi
    return 1
}

# Enumerate available roles from both directories (comma-separated)
list_available_roles() {
    local roles=()
    local work="${WORK_DIR:-.}"
    if [[ -d "${work}/.kimi/agents" ]]; then
        local f
        for f in "${work}/.kimi/agents"/*.yaml; do
            [[ -f "$f" ]] && roles+=("$(basename "$f" .yaml)")
        done
    fi
    if [[ -d "${SCRIPT_DIR}/../.kimi/agents" ]]; then
        local f
        for f in "${SCRIPT_DIR}/../.kimi/agents"/*.yaml; do
            [[ -f "$f" ]] && roles+=("$(basename "$f" .yaml)")
        done
    fi
    if [[ ${#roles[@]} -eq 0 ]]; then return 0; fi
    printf '%s\n' "${roles[@]}" | sort -u | paste -sd ',' - | sed 's/,/, /g'
}

# Error with available roles list, then exit
die_role_not_found() {
    local role="$1"
    local work="${WORK_DIR:-.}"
    echo "Error: role '$role' not found." >&2
    local available
    available=$(list_available_roles)
    if [[ -n "$available" ]]; then
        echo "Available roles: $available" >&2
    else
        echo "No agent files found in ${work}/.kimi/agents/ or ${SCRIPT_DIR}/../.kimi/agents/" >&2
    fi
    exit "$EXIT_ROLE_NOT_FOUND"
}

# -- Usage -------------------------------------------------------------------

usage() {
    cat >&2 <<'USAGE_EOF'
Usage: kimi.agent.wrapper.sh [OPTIONS] PROMPT

Options:
  -r, --role ROLE      Agent role (maps to .kimi/agents/ROLE.yaml)
  -m, --model MODEL    Kimi model (default: kimi-for-coding)
  -w, --work-dir PATH  Working directory for Kimi
  -h, --help           Show this help

Prompt can also be piped via stdin.
Unknown flags are passed through to kimi CLI.
USAGE_EOF
    exit 0
}

# -- Argument parsing --------------------------------------------------------

while [[ $# -gt 0 ]]; do
    case "$1" in
        -r|--role)
            [[ -z "${2:-}" ]] && die "Option $1 requires an argument" "$EXIT_BAD_ARGS"
            ROLE="$2"; shift 2 ;;
        -m|--model)
            [[ -z "${2:-}" ]] && die "Option $1 requires an argument" "$EXIT_BAD_ARGS"
            MODEL="$2"; shift 2 ;;
        -w|--work-dir)
            [[ -z "${2:-}" ]] && die "Option $1 requires an argument" "$EXIT_BAD_ARGS"
            WORK_DIR="$2"; shift 2 ;;
        -h|--help)
            usage ;;
        --)
            shift
            [[ $# -gt 0 ]] && { PROMPT="$*"; shift $#; }
            ;;
        -*)
            PASSTHROUGH_ARGS+=("$1")
            if [[ -n "${2:-}" && ! "${2:-}" =~ ^- ]]; then
                PASSTHROUGH_ARGS+=("$2"); shift
            fi
            shift ;;
        *)
            PROMPT="$1"; shift ;;
    esac
done

# Check for piped stdin if no prompt from positional argument
if [[ -z "$PROMPT" && ! -t 0 ]]; then
    PROMPT=$(cat)
fi

# Require a prompt
if [[ -z "$PROMPT" ]]; then
    die "No prompt provided. Usage: kimi.agent.wrapper.sh [-r role] [-m model] \"prompt\"" "$EXIT_NO_PROMPT"
fi

# -- Validation --------------------------------------------------------------

# Step 1: Find kimi binary (dies with install instructions if not found)
KIMI_BIN=$(find_kimi)

# Step 2: Check version (warns if below minimum, continues anyway)
check_version

# Step 3: Resolve agent file if a role was specified
if [[ -n "$ROLE" ]]; then
    resolved=$(resolve_agent "$ROLE") || true
    if [[ -z "$resolved" ]]; then
        die_role_not_found "$ROLE"
    fi
    AGENT_FILE="$resolved"
fi

# -- Command construction and invocation -------------------------------------

# Build command as array (never eval or string concatenation)
# --quiet = --print --output-format text --final-message-only (implies --yolo)
cmd=("$KIMI_BIN" "--quiet")

# Add agent file if a role was resolved
[[ -n "$AGENT_FILE" ]] && cmd+=("--agent-file" "$AGENT_FILE")

# Add model (default or user-specified)
cmd+=("--model" "$MODEL")

# Add working directory if specified
[[ -n "$WORK_DIR" ]] && cmd+=("--work-dir" "$WORK_DIR")

# Add passthrough arguments (unknown flags forwarded to kimi CLI)
if [[ ${#PASSTHROUGH_ARGS[@]} -gt 0 ]]; then
    cmd+=("${PASSTHROUGH_ARGS[@]}")
fi

# Add prompt as final argument
cmd+=("--prompt" "$PROMPT")

# Emit machine-parseable header to stderr (Phase 5 Claude Code integration)
echo "[kimi:${ROLE:-none}:${MODEL}]" >&2

# Execute kimi and propagate its exit code
kimi_exit=0
"${cmd[@]}" || kimi_exit=$?
exit "$kimi_exit"
