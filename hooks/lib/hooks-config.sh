#!/bin/bash
#
# Hooks Configuration Library for Kimi Git Hooks
#
# Purpose: Load and access configuration from defaults, user config, project config,
#          and environment variables with proper precedence.
#
# Usage:
#   source "${HOOKS_ROOT}/lib/hooks-config.sh"
#   hooks_config_load
#   if hooks_config_is_enabled "pre-commit"; then
#       timeout=$(hooks_config_timeout "pre-commit")
#   fi
#
# Configuration Precedence (highest to lowest):
#   1. Environment variables (KIMI_HOOKS_*)
#   2. Project config (.kimi/hooks.json)
#   3. User config (~/.config/kimi/hooks.json)
#   4. Default config (hooks/config/default.json)
#
# Dependencies: jq (JSON parsing)

# Global configuration variables (set by hooks_config_load)
HOOKS_CONFIG_VERSION=""
HOOKS_CONFIG_ENABLED_HOOKS=""
HOOKS_CONFIG_TIMEOUT=""
HOOKS_CONFIG_AUTO_FIX=""
HOOKS_CONFIG_DRY_RUN=""
HOOKS_CONFIG_FILE_PATTERNS=""
HOOKS_CONFIG_BYPASS_ENV_VAR=""
HOOKS_CONFIG_HOOKS=""

# ============================================================================
# Configuration Loading
# ============================================================================

# Load configuration from all sources with proper precedence
# Sets global HOOKS_CONFIG_* variables
# Logs loading status to stderr
hooks_config_load() {
    local default_config=""
    local user_config="${HOME}/.config/kimi/hooks.json"
    local project_config=""
    
    # Determine default config location
    if [[ -n "${HOOKS_ROOT}" ]]; then
        default_config="${HOOKS_ROOT}/config/default.json"
    else
        # Try to find relative to this script
        local script_dir
        script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        default_config="${script_dir}/../config/default.json"
    fi
    
    # Determine project config location
    if [[ -n "${KIMI_HOOKS_PROJECT_ROOT}" ]]; then
        project_config="${KIMI_HOOKS_PROJECT_ROOT}/.kimi/hooks.json"
    else
        # Try to find git root
        local git_root
        git_root=$(git rev-parse --show-toplevel 2>/dev/null || echo "")
        if [[ -n "$git_root" ]]; then
            project_config="${git_root}/.kimi/hooks.json"
        fi
    fi
    
    # Check if default config exists
    if [[ ! -f "$default_config" ]]; then
        echo "Error: Default config not found at $default_config" >&2
        return 1
    fi
    
    # Start with defaults
    HOOKS_CONFIG_VERSION=$(jq -r '.version // "1.0"' "$default_config")
    HOOKS_CONFIG_ENABLED_HOOKS=$(jq -c '.enabled_hooks // []' "$default_config")
    HOOKS_CONFIG_TIMEOUT=$(jq -r '.timeout_seconds // 60' "$default_config")
    HOOKS_CONFIG_AUTO_FIX=$(jq -r '.auto_fix // false' "$default_config")
    HOOKS_CONFIG_DRY_RUN=$(jq -r '.dry_run // false' "$default_config")
    HOOKS_CONFIG_FILE_PATTERNS=$(jq -c '.file_patterns // []' "$default_config")
    HOOKS_CONFIG_BYPASS_ENV_VAR=$(jq -r '.bypass_env_var // "KIMI_HOOKS_SKIP"' "$default_config")
    HOOKS_CONFIG_HOOKS=$(jq -c '.hooks // {}' "$default_config")
    
    echo "Loaded defaults from: $default_config" >&2
    
    # Override with user config if exists
    if [[ -f "$user_config" ]]; then
        echo "Loading user config from: $user_config" >&2
        _hooks_config_merge "$user_config" "user"
    else
        echo "No user config found at: $user_config" >&2
    fi
    
    # Override with project config if exists (higher precedence than user)
    if [[ -f "$project_config" ]]; then
        echo "Loading project config from: $project_config" >&2
        _hooks_config_merge "$project_config" "project"
    else
        echo "No project config found at: $project_config" >&2
    fi
    
    # Override with environment variables (highest precedence)
    if [[ -n "${KIMI_HOOKS_ENABLED_HOOKS:-}" ]]; then
        HOOKS_CONFIG_ENABLED_HOOKS=$(echo "[${KIMI_HOOKS_ENABLED_HOOKS}]" | jq -c '.')
        echo "Overriding enabled_hooks from environment" >&2
    fi
    
    if [[ -n "${KIMI_HOOKS_TIMEOUT:-}" ]]; then
        HOOKS_CONFIG_TIMEOUT="${KIMI_HOOKS_TIMEOUT}"
        echo "Overriding timeout from environment: ${KIMI_HOOKS_TIMEOUT}" >&2
    fi
    
    if [[ -n "${KIMI_HOOKS_AUTO_FIX:-}" ]]; then
        HOOKS_CONFIG_AUTO_FIX="${KIMI_HOOKS_AUTO_FIX}"
        echo "Overriding auto_fix from environment: ${KIMI_HOOKS_AUTO_FIX}" >&2
    fi
    
    if [[ -n "${KIMI_HOOKS_DRY_RUN:-}" ]]; then
        HOOKS_CONFIG_DRY_RUN="${KIMI_HOOKS_DRY_RUN}"
        echo "Overriding dry_run from environment: ${KIMI_HOOKS_DRY_RUN}" >&2
    fi
    
    if [[ -n "${KIMI_HOOKS_FILE_PATTERNS:-}" ]]; then
        HOOKS_CONFIG_FILE_PATTERNS=$(echo "[${KIMI_HOOKS_FILE_PATTERNS}]" | jq -c '.')
        echo "Overriding file_patterns from environment" >&2
    fi
    
    if [[ -n "${KIMI_HOOKS_BYPASS_VAR:-}" ]]; then
        HOOKS_CONFIG_BYPASS_ENV_VAR="${KIMI_HOOKS_BYPASS_VAR}"
        echo "Overriding bypass_env_var from environment: ${KIMI_HOOKS_BYPASS_VAR}" >&2
    fi
    
    # Validate configuration values
    _hooks_config_validate
    
    echo "Configuration loaded successfully" >&2
    echo "  - version: $HOOKS_CONFIG_VERSION" >&2
    echo "  - timeout: $HOOKS_CONFIG_TIMEOUT" >&2
    echo "  - auto_fix: $HOOKS_CONFIG_AUTO_FIX" >&2
    echo "  - dry_run: $HOOKS_CONFIG_DRY_RUN" >&2
    
    return 0
}

# Internal: Merge config from a file into global variables
# Args:
#   $1 - Config file path
#   $2 - Source name (for logging)
_hooks_config_merge() {
    local config_file="$1"
    local source="$2"
    
    local val
    
    val=$(jq -r '.timeout_seconds // empty' "$config_file")
    if [[ -n "$val" ]]; then
        HOOKS_CONFIG_TIMEOUT="$val"
        echo "  - timeout from $source config: $val" >&2
    fi
    
    val=$(jq -r '.auto_fix // empty' "$config_file")
    if [[ -n "$val" && "$val" != "null" ]]; then
        HOOKS_CONFIG_AUTO_FIX="$val"
        echo "  - auto_fix from $source config: $val" >&2
    fi
    
    val=$(jq -r '.dry_run // empty' "$config_file")
    if [[ -n "$val" && "$val" != "null" ]]; then
        HOOKS_CONFIG_DRY_RUN="$val"
        echo "  - dry_run from $source config: $val" >&2
    fi
    
    val=$(jq -c '.enabled_hooks // empty' "$config_file")
    if [[ -n "$val" && "$val" != "null" && "$val" != "[]" ]]; then
        HOOKS_CONFIG_ENABLED_HOOKS="$val"
        echo "  - enabled_hooks from $source config" >&2
    fi
    
    val=$(jq -c '.file_patterns // empty' "$config_file")
    if [[ -n "$val" && "$val" != "null" && "$val" != "[]" ]]; then
        HOOKS_CONFIG_FILE_PATTERNS="$val"
        echo "  - file_patterns from $source config" >&2
    fi
    
    val=$(jq -r '.bypass_env_var // empty' "$config_file")
    if [[ -n "$val" && "$val" != "null" ]]; then
        HOOKS_CONFIG_BYPASS_ENV_VAR="$val"
        echo "  - bypass_env_var from $source config: $val" >&2
    fi
    
    val=$(jq -c '.hooks // empty' "$config_file")
    if [[ -n "$val" && "$val" != "null" && "$val" != "{}" ]]; then
        # Merge hook-specific configs (project overrides user, user overrides default)
        HOOKS_CONFIG_HOOKS=$(echo "${HOOKS_CONFIG_HOOKS}${val}" | jq -s '.[0] * .[1]')
        echo "  - hooks from $source config" >&2
    fi
}

# Internal: Validate configuration values
_hooks_config_validate() {
    # Validate timeout (must be positive integer)
    if ! [[ "$HOOKS_CONFIG_TIMEOUT" =~ ^[0-9]+$ ]] || [[ "$HOOKS_CONFIG_TIMEOUT" -le 0 ]]; then
        echo "Warning: Invalid timeout '$HOOKS_CONFIG_TIMEOUT', defaulting to 60" >&2
        HOOKS_CONFIG_TIMEOUT="60"
    fi
    
    # Validate auto_fix (must be boolean-like)
    if [[ "$HOOKS_CONFIG_AUTO_FIX" != "true" && "$HOOKS_CONFIG_AUTO_FIX" != "false" ]]; then
        echo "Warning: Invalid auto_fix '$HOOKS_CONFIG_AUTO_FIX', defaulting to false" >&2
        HOOKS_CONFIG_AUTO_FIX="false"
    fi
    
    # Validate dry_run (must be boolean-like)
    if [[ "$HOOKS_CONFIG_DRY_RUN" != "true" && "$HOOKS_CONFIG_DRY_RUN" != "false" ]]; then
        echo "Warning: Invalid dry_run '$HOOKS_CONFIG_DRY_RUN', defaulting to false" >&2
        HOOKS_CONFIG_DRY_RUN="false"
    fi
}

# ============================================================================
# Configuration Access Functions
# ============================================================================

# Get a configuration value by key path
# Args:
#   $1 - Key path (e.g., "timeout_seconds", "hooks.pre-commit.enabled")
# Output:
#   Echoes the configuration value
hooks_config_get() {
    local key_path="$1"
    local result=""
    
    case "$key_path" in
        "version")
            result="$HOOKS_CONFIG_VERSION"
            ;;
        "timeout_seconds")
            result="$HOOKS_CONFIG_TIMEOUT"
            ;;
        "auto_fix")
            result="$HOOKS_CONFIG_AUTO_FIX"
            ;;
        "dry_run")
            result="$HOOKS_CONFIG_DRY_RUN"
            ;;
        "bypass_env_var")
            result="$HOOKS_CONFIG_BYPASS_ENV_VAR"
            ;;
        "enabled_hooks")
            echo "$HOOKS_CONFIG_ENABLED_HOOKS"
            return 0
            ;;
        "file_patterns")
            echo "$HOOKS_CONFIG_FILE_PATTERNS"
            return 0
            ;;
        hooks.*)
            # Extract hook-specific value using jq
            local hook_key="${key_path#hooks.}"
            result=$(echo "$HOOKS_CONFIG_HOOKS" | jq -r ".${hook_key} // empty")
            ;;
        *)
            echo "Error: Unknown config key '$key_path'" >&2
            return 1
            ;;
    esac
    
    echo "$result"
}

# Check if a specific hook type is enabled
# Args:
#   $1 - Hook type (pre-commit, post-checkout, pre-push)
# Returns:
#   0 if enabled, 1 if disabled or not found
hooks_config_is_enabled() {
    local hook_type="$1"
    
    # Check if hook is in enabled_hooks array
    local is_in_list
    is_in_list=$(echo "$HOOKS_CONFIG_ENABLED_HOOKS" | jq -r "index(\"$hook_type\") // empty")
    
    if [[ -z "$is_in_list" ]]; then
        return 1
    fi
    
    # Check hook-specific enabled setting
    local hook_enabled
    hook_enabled=$(echo "$HOOKS_CONFIG_HOOKS" | jq -r ".[\"$hook_type\"].enabled // empty")
    
    if [[ -n "$hook_enabled" && "$hook_enabled" == "false" ]]; then
        return 1
    fi
    
    return 0
}

# Get timeout with hook-specific override support
# Args:
#   $1 - Hook type (optional, returns global timeout if not specified)
# Output:
#   Echoes timeout in seconds
hooks_config_timeout() {
    local hook_type="${1:-}"
    
    if [[ -n "$hook_type" ]]; then
        # Check for hook-specific timeout
        local hook_timeout
        hook_timeout=$(echo "$HOOKS_CONFIG_HOOKS" | jq -r ".[\"$hook_type\"].timeout_seconds // empty")
        if [[ -n "$hook_timeout" && "$hook_timeout" != "null" ]]; then
            echo "$hook_timeout"
            return 0
        fi
    fi
    
    echo "$HOOKS_CONFIG_TIMEOUT"
}

# Get auto_fix setting for a specific hook
# Args:
#   $1 - Hook type (optional, returns global auto_fix if not specified)
# Output:
#   Echoes "true" or "false"
hooks_config_auto_fix() {
    local hook_type="${1:-}"
    
    if [[ -n "$hook_type" ]]; then
        # Check for hook-specific auto_fix
        local hook_auto_fix
        hook_auto_fix=$(echo "$HOOKS_CONFIG_HOOKS" | jq -r ".[\"$hook_type\"].auto_fix // empty")
        if [[ -n "$hook_auto_fix" && "$hook_auto_fix" != "null" ]]; then
            echo "$hook_auto_fix"
            return 0
        fi
    fi
    
    echo "$HOOKS_CONFIG_AUTO_FIX"
}

# Get file patterns array
# Output:
#   Echoes JSON array of file patterns
hooks_config_file_patterns() {
    echo "$HOOKS_CONFIG_FILE_PATTERNS"
}

# Check if dry-run mode is enabled
# Output:
#   Echoes "true" or "false"
hooks_config_is_dry_run() {
    echo "$HOOKS_CONFIG_DRY_RUN"
}

# Check if hooks should be bypassed (via environment variable)
# Returns:
#   0 if should bypass, 1 if should run normally
hooks_config_should_bypass() {
    local bypass_var="$HOOKS_CONFIG_BYPASS_ENV_VAR"
    local bypass_value="${!bypass_var:-}"
    
    if [[ -n "$bypass_value" && "$bypass_value" != "0" && "$bypass_value" != "false" ]]; then
        return 0
    fi
    
    return 1
}

# ============================================================================
# Helper Functions
# ============================================================================

# Ensure config directory exists
# Creates ~/.config/kimi/ if it doesn't exist
hooks_config_ensure_dir() {
    local config_dir="${HOME}/.config/kimi"
    
    if [[ ! -d "$config_dir" ]]; then
        mkdir -p "$config_dir"
        echo "Created config directory: $config_dir" >&2
    fi
}

# Export user configuration template
# Creates a template config file at ~/.config/kimi/hooks.json
# with current settings as defaults
hooks_config_export_template() {
    local user_config="${HOME}/.config/kimi/hooks.json"
    
    hooks_config_ensure_dir
    
    # Create template config
    cat > "$user_config" <<EOF
{
  "version": "${HOOKS_CONFIG_VERSION}",
  "enabled_hooks": ${HOOKS_CONFIG_ENABLED_HOOKS},
  "timeout_seconds": ${HOOKS_CONFIG_TIMEOUT},
  "auto_fix": ${HOOKS_CONFIG_AUTO_FIX},
  "dry_run": ${HOOKS_CONFIG_DRY_RUN},
  "file_patterns": ${HOOKS_CONFIG_FILE_PATTERNS},
  "bypass_env_var": "${HOOKS_CONFIG_BYPASS_ENV_VAR}",
  "hooks": ${HOOKS_CONFIG_HOOKS}
}
EOF
    
    echo "Exported config template to: $user_config" >&2
}

# Check if jq is available
# Returns:
#   0 if jq is available, 1 otherwise
hooks_config_has_jq() {
    command -v jq &>/dev/null
}

# Get list of enabled hook types
# Output:
#   Space-separated list of hook types
hooks_config_list_enabled() {
    echo "$HOOKS_CONFIG_ENABLED_HOOKS" | jq -r '.[]' | tr '\n' ' '
}
