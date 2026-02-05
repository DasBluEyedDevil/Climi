#!/bin/bash
#
# Configuration Management Library for Kimi MCP Server
#
# Purpose: Load and access configuration from defaults, user config file,
#          and environment variables with proper precedence.
#
# Usage:
#   source "${MCP_BRIDGE_ROOT}/lib/config.sh"
#   mcp_config_load
#   model=$(mcp_config_model)
#   timeout=$(mcp_config_timeout)
#
# Configuration Precedence (highest to lowest):
#   1. Environment variables (KIMI_MCP_MODEL, KIMI_MCP_TIMEOUT, etc.)
#   2. User config file (~/.config/kimi-mcp/config.json)
#   3. Default config file (mcp-bridge/config/default.json)
#
# Dependencies: jq (JSON parsing)

# Global configuration variables (set by mcp_config_load)
MCP_CONFIG_MODEL=""
MCP_CONFIG_TIMEOUT=""
MCP_CONFIG_MAX_FILE_SIZE=""
MCP_CONFIG_ROLES=""

# ============================================================================
# Configuration Loading
# ============================================================================

# Load configuration from all sources with proper precedence
# Sets global MCP_CONFIG_* variables
# Logs loading status to stderr
mcp_config_load() {
    local user_config="${HOME}/.config/kimi-mcp/config.json"
    local default_config=""
    
    # Determine default config location
    if [[ -n "${MCP_BRIDGE_ROOT}" ]]; then
        default_config="${MCP_BRIDGE_ROOT}/config/default.json"
    else
        # Try to find relative to this script
        local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        default_config="${script_dir}/../config/default.json"
    fi
    
    # Check if default config exists
    if [[ ! -f "$default_config" ]]; then
        echo "Error: Default config not found at $default_config" >&2
        return 1
    fi
    
    # Start with defaults
    MCP_CONFIG_MODEL=$(jq -r '.model // "k2"' "$default_config")
    MCP_CONFIG_TIMEOUT=$(jq -r '.timeout // 30' "$default_config")
    MCP_CONFIG_MAX_FILE_SIZE=$(jq -r '.max_file_size // 1048576' "$default_config")
    MCP_CONFIG_ROLES=$(jq -c '.roles // {}' "$default_config")
    
    echo "Loaded defaults from: $default_config" >&2
    
    # Override with user config if exists
    if [[ -f "$user_config" ]]; then
        echo "Loading user config from: $user_config" >&2
        
        local user_model
        user_model=$(jq -r '.model // empty' "$user_config")
        if [[ -n "$user_model" ]]; then
            MCP_CONFIG_MODEL="$user_model"
            echo "  - model from user config: $user_model" >&2
        fi
        
        local user_timeout
        user_timeout=$(jq -r '.timeout // empty' "$user_config")
        if [[ -n "$user_timeout" ]]; then
            MCP_CONFIG_TIMEOUT="$user_timeout"
            echo "  - timeout from user config: $user_timeout" >&2
        fi
        
        local user_max_file_size
        user_max_file_size=$(jq -r '.max_file_size // empty' "$user_config")
        if [[ -n "$user_max_file_size" ]]; then
            MCP_CONFIG_MAX_FILE_SIZE="$user_max_file_size"
            echo "  - max_file_size from user config: $user_max_file_size" >&2
        fi
        
        local user_roles
        user_roles=$(jq -c '.roles // empty' "$user_config")
        if [[ -n "$user_roles" && "$user_roles" != "{}" ]]; then
            MCP_CONFIG_ROLES="$user_roles"
            echo "  - roles from user config" >&2
        fi
    else
        echo "No user config found at: $user_config (using defaults)" >&2
    fi
    
    # Override with environment variables (highest precedence)
    if [[ -n "${KIMI_MCP_MODEL:-}" ]]; then
        MCP_CONFIG_MODEL="${KIMI_MCP_MODEL}"
        echo "Overriding model from environment: ${KIMI_MCP_MODEL}" >&2
    fi

    if [[ -n "${KIMI_MCP_TIMEOUT:-}" ]]; then
        MCP_CONFIG_TIMEOUT="${KIMI_MCP_TIMEOUT}"
        echo "Overriding timeout from environment: ${KIMI_MCP_TIMEOUT}" >&2
    fi

    if [[ -n "${KIMI_MCP_MAX_FILE_SIZE:-}" ]]; then
        MCP_CONFIG_MAX_FILE_SIZE="${KIMI_MCP_MAX_FILE_SIZE}"
        echo "Overriding max_file_size from environment: ${KIMI_MCP_MAX_FILE_SIZE}" >&2
    fi
    
    # Validate configuration values
    _mcp_config_validate
    
    echo "Configuration loaded successfully" >&2
    echo "  - model: $MCP_CONFIG_MODEL" >&2
    echo "  - timeout: $MCP_CONFIG_TIMEOUT" >&2
    echo "  - max_file_size: $MCP_CONFIG_MAX_FILE_SIZE" >&2
    
    return 0
}

# Internal: Validate configuration values
_mcp_config_validate() {
    # Validate model (only k2 or k2.5 allowed)
    if [[ "$MCP_CONFIG_MODEL" != "k2" && "$MCP_CONFIG_MODEL" != "k2.5" ]]; then
        echo "Warning: Invalid model '$MCP_CONFIG_MODEL', defaulting to k2" >&2
        MCP_CONFIG_MODEL="k2"
    fi
    
    # Validate timeout (must be positive integer)
    if ! [[ "$MCP_CONFIG_TIMEOUT" =~ ^[0-9]+$ ]] || [[ "$MCP_CONFIG_TIMEOUT" -le 0 ]]; then
        echo "Warning: Invalid timeout '$MCP_CONFIG_TIMEOUT', defaulting to 30" >&2
        MCP_CONFIG_TIMEOUT="30"
    fi
    
    # Validate max_file_size (must be positive integer)
    if ! [[ "$MCP_CONFIG_MAX_FILE_SIZE" =~ ^[0-9]+$ ]] || [[ "$MCP_CONFIG_MAX_FILE_SIZE" -le 0 ]]; then
        echo "Warning: Invalid max_file_size '$MCP_CONFIG_MAX_FILE_SIZE', defaulting to 1048576" >&2
        MCP_CONFIG_MAX_FILE_SIZE="1048576"
    fi
}

# ============================================================================
# Configuration Access Functions
# ============================================================================

# Get a configuration value by key
# Args:
#   $1 - Key name (model, timeout, max_file_size)
# Output:
#   Echoes the configuration value
mcp_config_get() {
    local key="$1"
    
    case "$key" in
        "model")
            echo "$MCP_CONFIG_MODEL"
            ;;
        "timeout")
            echo "$MCP_CONFIG_TIMEOUT"
            ;;
        "max_file_size")
            echo "$MCP_CONFIG_MAX_FILE_SIZE"
            ;;
        *)
            echo "Error: Unknown config key '$key'" >&2
            return 1
            ;;
    esac
}

# Get the current model setting
# Output:
#   Echoes "k2" or "k2.5"
mcp_config_model() {
    echo "$MCP_CONFIG_MODEL"
}

# Get the current timeout in seconds
# Output:
#   Echoes timeout as integer
mcp_config_timeout() {
    echo "$MCP_CONFIG_TIMEOUT"
}

# Get the max file size in bytes
# Output:
#   Echoes max file size as integer
mcp_config_max_file_size() {
    echo "$MCP_CONFIG_MAX_FILE_SIZE"
}

# Get system prompt for a role
# Args:
#   $1 - Role name (general, security, performance, refactor)
# Output:
#   Echoes the system prompt string
#   Falls back to "general" role if specified role not found
mcp_config_role() {
    local role_name="${1:-general}"
    
    # Extract role from roles JSON using jq
    local prompt
    prompt=$(echo "$MCP_CONFIG_ROLES" | jq -r ".[\"$role_name\"] // empty")
    
    # If role not found, fall back to general
    if [[ -z "$prompt" ]]; then
        if [[ "$role_name" != "general" ]]; then
            echo "Warning: Unknown role '$role_name', falling back to 'general'" >&2
        fi
        prompt=$(echo "$MCP_CONFIG_ROLES" | jq -r '.general // "You are a helpful coding assistant."')
    fi
    
    echo "$prompt"
}

# Ensure config directory exists
# Creates ~/.config/kimi-mcp/ if it doesn't exist
mcp_config_ensure_dir() {
    local config_dir="${HOME}/.config/kimi-mcp"
    
    if [[ ! -d "$config_dir" ]]; then
        mkdir -p "$config_dir"
        echo "Created config directory: $config_dir" >&2
    fi
}

# Export user configuration template
# Creates a template config file at ~/.config/kimi-mcp/config.json
# with current settings as defaults
mcp_config_export_template() {
    local user_config="${HOME}/.config/kimi-mcp/config.json"
    
    mcp_config_ensure_dir
    
    # Create template config
    cat > "$user_config" <<EOF
{
  "model": "${MCP_CONFIG_MODEL}",
  "timeout": ${MCP_CONFIG_TIMEOUT},
  "max_file_size": ${MCP_CONFIG_MAX_FILE_SIZE},
  "roles": ${MCP_CONFIG_ROLES}
}
EOF
    
    echo "Exported config template to: $user_config" >&2
}
