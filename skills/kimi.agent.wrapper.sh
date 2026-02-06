#!/usr/bin/env bash
# kimi.agent.wrapper.sh -- Kimi CLI wrapper with role-based agent selection
# All wrapper output goes to stderr; only Kimi's output goes to stdout.
#
# Usage: kimi.agent.wrapper.sh [OPTIONS] PROMPT
#   -r, --role ROLE      Agent role (maps to .kimi/agents/ROLE.yaml)
#   -m, --model MODEL    Kimi model (default: kimi-code/kimi-for-coding)
#   -w, --work-dir PATH  Working directory for Kimi
#   -t, --template TPL   Template to prepend (maps to .kimi/templates/TPL.md)
#   --diff               Include git diff in prompt context
#   --dry-run            Show constructed command without executing
#   --verbose            Show wrapper debug output
#   -h, --help           Show this help
#
# Prompt can also be piped via stdin.
#
# Pass-through flags: Unknown flags (like --thinking, --no-thinking, -y, --yolo)
# are forwarded directly to the kimi CLI. This allows using any kimi CLI option
# without wrapper changes. Example: --thinking enables deeper reasoning mode.

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
readonly EXIT_TEMPLATE_NOT_FOUND=14

# -- Defaults ----------------------------------------------------------------
DEFAULT_MODEL="kimi-code/kimi-for-coding"
MIN_VERSION="1.7.0"
ROLE=""
MODEL="$DEFAULT_MODEL"
WORK_DIR=""
PROMPT=""
AGENT_FILE=""
DIFF_MODE=false
TEMPLATE=""
VERBOSE=false
DRY_RUN=false
PASSTHROUGH_ARGS=()

# -- Auto-Model Selection ----------------------------------------------------
AUTO_MODEL_ENABLED=false
SHOW_COST=false
CONFIDENCE_THRESHOLD=75
COST_THRESHOLD=10000
SELECTED_MODEL=""
MODEL_CONFIDENCE=0

# -- Session Management ------------------------------------------------------
SESSION_ID="${KIMI_SESSION_ID:-}"
SESSION_FILE=""

# -- Utility functions -------------------------------------------------------

die() { echo "Error: $1" >&2; exit "${2:-1}"; }
warn() { echo "Warning: $1" >&2; }

log_verbose() {
    [[ "$VERBOSE" == "true" ]] || return 0
    echo "[verbose] $*" >&2
}

log_model_selection() {
    echo "[model-selection] $*" >&2
}

log_session() {
    echo "[session] $*" >&2
}

# Capture git diff output for injection into prompt context
capture_git_diff() {
    local work_dir="${1:-.}"
    local diff_output=""
    
    # Check if git is available
    if ! command -v git >/dev/null 2>&1; then
        warn "git not found, skipping diff injection"
        return 1
    fi
    
    # Check if in a git repo
    if ! git -C "$work_dir" rev-parse --git-dir >/dev/null 2>&1; then
        warn "Not a git repository, skipping diff injection"
        return 1
    fi
    
    # Capture diff: staged + unstaged vs HEAD
    diff_output=$(git -C "$work_dir" diff HEAD 2>/dev/null) || {
        warn "Could not capture git diff"
        return 1
    }

    log_verbose "Git diff captured: ${#diff_output} chars"
    
    # Only output if there are changes
    if [[ -n "$diff_output" ]]; then
        printf '## Git Changes (diff vs HEAD)\n\n```diff\n%s\n```\n' "$diff_output"
    fi
}

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

# Load context file from project if present (silent continue if not found)
load_context_file() {
    local work_dir="${1:-.}"
    local context_content=""
    local context_file=""
    
    # Search order: .kimi/context.md first, then KimiContext.md
    if [[ -f "${work_dir}/.kimi/context.md" ]]; then
        context_file="${work_dir}/.kimi/context.md"
    elif [[ -f "${work_dir}/KimiContext.md" ]]; then
        context_file="${work_dir}/KimiContext.md"
    else
        # Silent continue - optional feature
        return 0
    fi
    
    log_verbose "Context file loaded: $context_file"

    # Read and output the context file content
    context_content=$(cat "$context_file")
    if [[ -n "$context_content" ]]; then
        printf '## Project Context (from %s)\n\n%s\n' "$(basename "$context_file")" "$context_content"
    fi
}

# Two-tier template resolution: project-local first, then global
resolve_template() {
    local template_name="$1"
    local work="${WORK_DIR:-.}"
    local project_template="${work}/.kimi/templates/${template_name}.md"
    local global_template="${SCRIPT_DIR}/../.kimi/templates/${template_name}.md"
    if [[ -f "$project_template" ]]; then
        echo "$project_template"
        return 0
    elif [[ -f "$global_template" ]]; then
        echo "$global_template"
        return 0
    fi
    return 1
}

# Enumerate available templates from both directories (comma-separated)
list_available_templates() {
    local templates=()
    local work="${WORK_DIR:-.}"
    if [[ -d "${work}/.kimi/templates" ]]; then
        local f
        for f in "${work}/.kimi/templates"/*.md; do
            [[ -f "$f" ]] && templates+=("$(basename "$f" .md)")
        done
    fi
    if [[ -d "${SCRIPT_DIR}/../.kimi/templates" ]]; then
        local f
        for f in "${SCRIPT_DIR}/../.kimi/templates"/*.md; do
            [[ -f "$f" ]] && templates+=("$(basename "$f" .md)")
        done
    fi
    if [[ ${#templates[@]} -eq 0 ]]; then return 0; fi
    printf '%s\n' "${templates[@]}" | sort -u | paste -sd ',' - | sed 's/,/, /g'
}

# Error with available templates list, then exit
die_template_not_found() {
    local template_name="$1"
    echo "Error: template '$template_name' not found." >&2
    local available
    available=$(list_available_templates)
    if [[ -n "$available" ]]; then
        echo "Available templates: $available" >&2
    else
        echo "No template files found in ${work}/.kimi/templates/ or ${SCRIPT_DIR}/../.kimi/templates/" >&2
    fi
    exit "$EXIT_TEMPLATE_NOT_FOUND"
}

# -- Auto-Model Selection Functions ------------------------------------------

# extract_file_paths(prompt)
# Extracts potential file paths from a prompt using regex
# Arguments:
#   $1 - Prompt text
# Returns:
#   Space-separated list of file paths
extract_file_paths() {
    local prompt="$1"
    local paths=""
    
    # Extract paths matching common file patterns
    # Pattern: alphanumeric, underscores, dots, slashes, ending with extension
    paths=$(echo "$prompt" | grep -oE '[[:alnum:]_./-]+\.[[:alnum:]]+' 2>/dev/null || true)
    
    # Filter to only include paths that exist
    local valid_paths=""
    for path in $paths; do
        # Check if it's a relative path from work dir
        local full_path="${WORK_DIR:-.}/$path"
        if [[ -f "$full_path" || -f "$path" ]]; then
            valid_paths="$valid_paths $path"
        fi
    done
    
    echo "$valid_paths" | tr ' ' '\n' | sort -u | tr '\n' ' '
}

# auto_select_model(prompt)
# Automatically selects the appropriate model based on task and files
# Arguments:
#   $1 - Prompt text
# Sets globals:
#   SELECTED_MODEL - The selected model (k2 or k2.5)
#   MODEL_CONFIDENCE - Confidence score (0-100)
auto_select_model() {
    local prompt="$1"
    # Try multiple paths for the selector
    local selector=""
    local possible_paths=(
        "${SCRIPT_DIR}/kimi-model-selector.sh"
        "${SCRIPT_DIR}/../skills/kimi-model-selector.sh"
        "./kimi-model-selector.sh"
        "$(pwd)/kimi-model-selector.sh"
    )
    
    for path in "${possible_paths[@]}"; do
        if [[ -f "$path" && -x "$path" ]]; then
            selector="$path"
            break
        fi
    done
    
    # Check if selector exists
    if [[ -z "$selector" ]]; then
        log_model_selection "Model selector not found in any expected location"
        SELECTED_MODEL="k2"
        MODEL_CONFIDENCE=50
        return 1
    fi
    
    # Extract file paths from prompt
    local files
    files=$(extract_file_paths "$prompt")
    
    # Build selector command
    local selector_cmd=("$selector" --task "$prompt" --json)
    # Trim whitespace and check if files is non-empty
    files=$(echo "$files" | tr -d '[:space:]')
    if [[ -n "$files" ]]; then
        # Convert space-separated to comma-separated
        local files_csv=""
        for f in $files; do
            [[ -n "$files_csv" ]] && files_csv="${files_csv},"
            files_csv="${files_csv}${f}"
        done
        selector_cmd+=(--files "$files_csv")
    fi
    
    log_verbose "Running model selector: ${selector_cmd[*]}"
    
    # Run selector and capture output
    local result
    if result=$("${selector_cmd[@]}" 2>/dev/null); then
        # Parse JSON result
        if command -v jq >/dev/null 2>&1; then
            SELECTED_MODEL=$(echo "$result" | jq -r '.model // "k2"')
            MODEL_CONFIDENCE=$(echo "$result" | jq -r '.confidence // 50')
            local override=$(echo "$result" | jq -r '.override // false')
            
            if [[ "$override" == "true" ]]; then
                log_model_selection "Override active: $SELECTED_MODEL (KIMI_FORCE_MODEL)"
            else
                log_model_selection "Selected: $SELECTED_MODEL (confidence: ${MODEL_CONFIDENCE}%)"
            fi
        else
            # Fallback: simple grep extraction
            SELECTED_MODEL=$(echo "$result" | grep -oP '"model":\s*"\K[^"]+' || echo "k2")
            MODEL_CONFIDENCE=$(echo "$result" | grep -oP '"confidence":\s*\K[0-9]+' || echo 50)
            log_model_selection "Selected: $SELECTED_MODEL (confidence: ${MODEL_CONFIDENCE}%)"
        fi
    else
        log_model_selection "Model selector failed, using default: k2"
        SELECTED_MODEL="k2"
        MODEL_CONFIDENCE=50
        return 1
    fi
}

# estimate_and_display_cost(prompt, model)
# Estimates cost and displays it to stderr
# Arguments:
#   $1 - Prompt text
#   $2 - Model name
# Returns:
#   Cost units (integer)
estimate_and_display_cost() {
    local prompt="$1"
    local model="${2:-k2}"
    # Try multiple paths for the estimator
    local estimator=""
    local possible_paths=(
        "${SCRIPT_DIR}/kimi-cost-estimator.sh"
        "${SCRIPT_DIR}/../skills/kimi-cost-estimator.sh"
        "./kimi-cost-estimator.sh"
        "$(pwd)/kimi-cost-estimator.sh"
    )
    
    for path in "${possible_paths[@]}"; do
        if [[ -f "$path" && -x "$path" ]]; then
            estimator="$path"
            break
        fi
    done
    
    # Check if estimator exists
    if [[ -z "$estimator" ]]; then
        log_verbose "Cost estimator not found in any expected location"
        return 1
    fi
    
    # Extract file paths
    local files
    files=$(extract_file_paths "$prompt")
    
    # Build estimator command
    local estimator_cmd=("$estimator" --prompt "$prompt" --model "$model")
    if [[ -n "$files" ]]; then
        local files_csv=""
        for f in $files; do
            [[ -n "$files_csv" ]] && files_csv="${files_csv},"
            files_csv="${files_csv}${f}"
        done
        estimator_cmd+=(--files "$files_csv")
    fi
    
    log_verbose "Running cost estimator: ${estimator_cmd[*]}"
    
    # Run estimator and capture cost
    local cost_output
    if cost_output=$("${estimator_cmd[@]}" 2>&1); then
        # Extract cost from output (format: "Cost estimate: ~N tokens (model, speed)")
        local cost_units
        if [[ "$cost_output" =~ ~([0-9,]+)\ tokens ]]; then
            # Remove commas and extract number
            cost_units=$(echo "${BASH_REMATCH[1]}" | tr -d ',')
        else
            cost_units=0
        fi
        
        log_model_selection "Cost estimate: $cost_output"
        echo "$cost_units"
        return 0
    else
        log_verbose "Cost estimation failed"
        return 1
    fi
}

# -- Session Management Functions --------------------------------------------

# get_session_id()
# Gets or generates a session ID for context preservation
# Returns:
#   Session ID string
get_session_id() {
    # If already set (from env var or previous call), return it
    if [[ -n "$SESSION_ID" ]]; then
        echo "$SESSION_ID"
        return 0
    fi
    
    # Generate new session ID: timestamp + random
    local timestamp
    timestamp=$(date +%s 2>/dev/null || echo "$(date +%s)" 2>/dev/null || echo "0")
    local random_suffix="${RANDOM:-$((RANDOM % 10000))}"
    
    SESSION_ID="kimi-${timestamp}-${random_suffix}"
    echo "$SESSION_ID"
}

# persist_session_id()
# Saves session ID to temp file for persistence
persist_session_id() {
    if [[ -z "$SESSION_ID" ]]; then
        return 1
    fi
    
    SESSION_FILE="/tmp/kimi-session-$$"
    echo "$SESSION_ID" > "$SESSION_FILE"
    
    # Set trap to clean up on exit
    trap 'rm -f "$SESSION_FILE"' EXIT
    
    log_session "Session persisted: $SESSION_ID"
}

# -- Usage -------------------------------------------------------------------

usage() {
    cat >&2 <<'USAGE_EOF'
kimi.agent.wrapper.sh -- Kimi CLI wrapper with role-based agent selection

Usage: kimi.agent.wrapper.sh [OPTIONS] PROMPT

Wrapper Options:
  -r, --role ROLE         Agent role (maps to .kimi/agents/ROLE.yaml)
  -m, --model MODEL       Kimi model (default: kimi-code/kimi-for-coding)
  -w, --work-dir PATH     Working directory for Kimi
  -t, --template TPL      Template to prepend (maps to .kimi/templates/TPL.md)
  --diff                  Include git diff (HEAD vs working tree) in prompt context
  --dry-run               Show command without executing
  --verbose               Show wrapper debug output
  -h, --help              Show this help and exit

Auto-Model Selection Options:
  --auto-model            Enable automatic model selection (K2 vs K2.5)
  --show-cost             Display cost estimate before delegation
  --confidence-threshold  N  Set confidence threshold (default: 75)

Session Management Options:
  --session-id ID         Explicit session ID for context preservation

Kimi CLI Options (pass-through):
  --thinking              Enable thinking mode for deeper reasoning
  --no-thinking           Disable thinking mode
  -y, --yes, --yolo       Auto-approve all actions
  --print                 Run in non-interactive print mode
  (and any other kimi CLI flags)

Environment Variables:
  KIMI_PATH               Override kimi binary location
  KIMI_FORCE_MODEL        Force model selection (k2 or k2.5)
  KIMI_SESSION_ID         Default session ID for context preservation
  KIMI_CONFIDENCE_THRESHOLD  Default confidence threshold
  KIMI_COST_THRESHOLD     Default cost threshold

Prompt can also be piped via stdin.
Unknown flags are passed through to kimi CLI.
USAGE_EOF

    local roles templates
    roles=$(list_available_roles)
    templates=$(list_available_templates)

    if [[ -n "$roles" ]]; then
        echo "" >&2
        echo "Available roles: $roles" >&2
    fi

    if [[ -n "$templates" ]]; then
        echo "" >&2
        echo "Available templates: $templates" >&2
    fi

    cat >&2 <<'EXAMPLES_EOF'

Examples:
  kimi.agent.wrapper.sh -r reviewer "Review this code"
  kimi.agent.wrapper.sh -r planner -t feature "Plan new feature"
  echo "prompt" | kimi.agent.wrapper.sh -r reviewer
  kimi.agent.wrapper.sh --diff -r auditor "Check changes"
  kimi.agent.wrapper.sh --thinking -r security "Audit this repo"
EXAMPLES_EOF

    exit 0
}

# -- Argument parsing --------------------------------------------------------

while [[ $# -gt 0 ]]; do
    case "$1" in
        -r|--role)
            [[ -z "${2:-}" ]] && die "Option $1 requires an argument" "$EXIT_BAD_ARGS"
            ROLE="$2"; shift 2 ;;
        -t|--template)
            [[ -z "${2:-}" ]] && die "Option $1 requires an argument" "$EXIT_BAD_ARGS"
            TEMPLATE="$2"; shift 2 ;;
        -m|--model)
            [[ -z "${2:-}" ]] && die "Option $1 requires an argument" "$EXIT_BAD_ARGS"
            MODEL="$2"; shift 2 ;;
        -w|--work-dir)
            [[ -z "${2:-}" ]] && die "Option $1 requires an argument" "$EXIT_BAD_ARGS"
            WORK_DIR="$2"; shift 2 ;;
        --diff)
            DIFF_MODE=true; shift ;;
        --verbose)
            VERBOSE=true; shift ;;
        --dry-run)
            DRY_RUN=true; shift ;;
        --auto-model)
            AUTO_MODEL_ENABLED=true; shift ;;
        --show-cost)
            SHOW_COST=true; shift ;;
        --confidence-threshold)
            [[ -z "${2:-}" ]] && die "Option $1 requires an argument" "$EXIT_BAD_ARGS"
            CONFIDENCE_THRESHOLD="$2"; shift 2 ;;
        --session-id)
            [[ -z "${2:-}" ]] && die "Option $1 requires an argument" "$EXIT_BAD_ARGS"
            SESSION_ID="$2"; shift 2 ;;
        -h|--help)
            usage ;;
        --)
            shift
            [[ $# -gt 0 ]] && { PROMPT="$*"; shift $#; }
            ;;
        -*)
            # Pass-through: Unknown flags go directly to kimi CLI
            # This handles --thinking, --no-thinking, -y, --yolo, --print, etc.
            # We only pass the flag itself, not the next arg (it might be the prompt).
            # For flags with values, use --flag=value syntax.
            PASSTHROUGH_ARGS+=("$1")
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
log_verbose "Resolved kimi binary: $KIMI_BIN"

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
log_verbose "Agent file: ${AGENT_FILE:-none}"

# Step 4: Resolve template if specified and assemble prompt
TEMPLATE_CONTENT=""
if [[ -n "$TEMPLATE" ]]; then
    template_path=$(resolve_template "$TEMPLATE") || true
    if [[ -z "$template_path" ]]; then
        die_template_not_found "$TEMPLATE"
    fi
    TEMPLATE_CONTENT=$(cat "$template_path")
fi
log_verbose "Template: ${TEMPLATE:-none}"

log_verbose "Model: $MODEL, Role: ${ROLE:-none}"

# -- Auto-Model Selection ----------------------------------------------------

# Step 5: Auto-model selection (if enabled)
if [[ "$AUTO_MODEL_ENABLED" == "true" ]]; then
    log_verbose "Auto-model selection enabled"
    
    # Check for user override first
    if [[ -n "${KIMI_FORCE_MODEL:-}" ]]; then
        normalized_override=$(echo "$KIMI_FORCE_MODEL" | tr '[:upper:]' '[:lower:]')
        if [[ "$normalized_override" == "k2" || "$normalized_override" == "k2.5" || "$normalized_override" == "k2_5" ]]; then
            if [[ "$normalized_override" == "k2_5" ]]; then
                normalized_override="k2.5"
            fi
            SELECTED_MODEL="$normalized_override"
            MODEL_CONFIDENCE=100
            log_model_selection "Override active: $SELECTED_MODEL (KIMI_FORCE_MODEL)"
        else
            log_warn "Invalid KIMI_FORCE_MODEL: $KIMI_FORCE_MODEL"
            auto_select_model "$PROMPT"
        fi
    else
        # Run auto-selection
        auto_select_model "$PROMPT"
    fi
    
    # Estimate and display cost if requested or confidence is low
    cost_units=0
    if [[ "$SHOW_COST" == "true" || $MODEL_CONFIDENCE -lt $CONFIDENCE_THRESHOLD ]]; then
        cost_units=$(estimate_and_display_cost "$PROMPT" "$SELECTED_MODEL" || echo 0)
    fi
    
    # Warn if confidence is low
    if [[ $MODEL_CONFIDENCE -lt $CONFIDENCE_THRESHOLD ]]; then
        log_model_selection "Warning: Low confidence ($MODEL_CONFIDENCE% < $CONFIDENCE_THRESHOLD%)"
        log_model_selection "Override with KIMI_FORCE_MODEL=k2 or k2.5"
    fi
    
    # Use selected model (prepend provider prefix for Kimi CLI format)
    MODEL="kimi-code/$SELECTED_MODEL"
    log_verbose "Final model selection: $MODEL"
fi

# -- Session Management ------------------------------------------------------

# Step 6: Setup session for context preservation
if [[ -z "$SESSION_ID" ]]; then
    SESSION_ID=$(get_session_id)
fi
persist_session_id
log_session "Using session: $SESSION_ID"

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

# Add session for context preservation
[[ -n "$SESSION_ID" ]] && cmd+=("--session" "$SESSION_ID")

# Add passthrough arguments (unknown flags forwarded to kimi CLI)
if [[ ${#PASSTHROUGH_ARGS[@]} -gt 0 ]]; then
    cmd+=("${PASSTHROUGH_ARGS[@]}")
fi
log_verbose "Passthrough args: ${PASSTHROUGH_ARGS[*]}"

# Step 8: Capture context file and git diff content
CONTEXT_SECTION=$(load_context_file "${WORK_DIR:-.}") || true
DIFF_SECTION=""
if [[ "$DIFF_MODE" == "true" ]]; then
    DIFF_SECTION=$(capture_git_diff "${WORK_DIR:-.}") || true
fi

# Step 9: Assemble final prompt in order: Template → Context → Diff → User prompt
ASSEMBLED_PROMPT="$PROMPT"

# Prepend diff if captured
if [[ -n "$DIFF_SECTION" ]]; then
    ASSEMBLED_PROMPT="${DIFF_SECTION}

${ASSEMBLED_PROMPT}"
fi

# Prepend context file if loaded
if [[ -n "$CONTEXT_SECTION" ]]; then
    ASSEMBLED_PROMPT="${CONTEXT_SECTION}

${ASSEMBLED_PROMPT}"
fi

# Prepend template if specified
if [[ -n "$TEMPLATE_CONTENT" ]]; then
    ASSEMBLED_PROMPT="${TEMPLATE_CONTENT}

${ASSEMBLED_PROMPT}"
fi

log_verbose "Prompt length: ${#ASSEMBLED_PROMPT} chars"
log_verbose "Dry-run mode: $DRY_RUN"

# Add prompt as final argument
cmd+=("--prompt" "$ASSEMBLED_PROMPT")

# Emit machine-parseable header to stderr (Phase 5 Claude Code integration)
echo "[kimi:${ROLE:-none}:${TEMPLATE:-none}:${MODEL}]" >&2

# Dry-run mode: show command without executing
if [[ "$DRY_RUN" == "true" ]]; then
    echo "[DRY-RUN] Constructed command:" >&2
    printf '  %q' "${cmd[0]}" >&2
    for ((i=1; i<${#cmd[@]}; i++)); do
        printf ' %q' "${cmd[$i]}" >&2
    done
    echo "" >&2
    
    # Show truncated prompt preview
    if [[ ${#ASSEMBLED_PROMPT} -gt 200 ]]; then
        echo "[DRY-RUN] Assembled prompt (${#ASSEMBLED_PROMPT} chars):" >&2
        echo "  ${ASSEMBLED_PROMPT:0:200}..." >&2
    else
        echo "[DRY-RUN] Assembled prompt:" >&2
        echo "  $ASSEMBLED_PROMPT" >&2
    fi
    
    exit 0
fi

# Execute kimi and propagate its exit code
# Set Python encoding for Windows compatibility (handles Unicode output from kimi)
export PYTHONIOENCODING=utf-8
kimi_exit=0
"${cmd[@]}" || kimi_exit=$?
exit "$kimi_exit"
