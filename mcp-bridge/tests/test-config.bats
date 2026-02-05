#!/usr/bin/env bats
#
# Tests for MCP Bridge Configuration Management
#
# Run with: bats test-config.bats

setup() {
    # Save original environment
    ORIGINAL_HOME="$HOME"
    ORIGINAL_MCP_BRIDGE_ROOT="${MCP_BRIDGE_ROOT:-}"
    ORIGINAL_KIMI_MCP_MODEL="${KIMI_MCP_MODEL:-}"
    ORIGINAL_KIMI_MCP_TIMEOUT="${KIMI_MCP_TIMEOUT:-}"
    ORIGINAL_KIMI_MCP_MAX_FILE_SIZE="${KIMI_MCP_MAX_FILE_SIZE:-}"
    
    # Set up test environment
    export MCP_BRIDGE_ROOT="${BATS_TEST_DIRNAME}/.."
    export HOME="${BATS_TEST_TMPDIR}/home"
    mkdir -p "$HOME/.config/kimi-mcp"
    
    # Source the config library
    source "${MCP_BRIDGE_ROOT}/lib/config.sh"
}

teardown() {
    # Restore original environment
    export HOME="$ORIGINAL_HOME"
    if [[ -n "$ORIGINAL_MCP_BRIDGE_ROOT" ]]; then
        export MCP_BRIDGE_ROOT="$ORIGINAL_MCP_BRIDGE_ROOT"
    else
        unset MCP_BRIDGE_ROOT
    fi
    if [[ -n "$ORIGINAL_KIMI_MCP_MODEL" ]]; then
        export KIMI_MCP_MODEL="$ORIGINAL_KIMI_MCP_MODEL"
    else
        unset KIMI_MCP_MODEL
    fi
    if [[ -n "$ORIGINAL_KIMI_MCP_TIMEOUT" ]]; then
        export KIMI_MCP_TIMEOUT="$ORIGINAL_KIMI_MCP_TIMEOUT"
    else
        unset KIMI_MCP_TIMEOUT
    fi
    if [[ -n "$ORIGINAL_KIMI_MCP_MAX_FILE_SIZE" ]]; then
        export KIMI_MCP_MAX_FILE_SIZE="$ORIGINAL_KIMI_MCP_MAX_FILE_SIZE"
    else
        unset KIMI_MCP_MAX_FILE_SIZE
    fi
}

# ============================================================================
# Test: Load defaults when no user config exists
# ============================================================================

@test "config loads defaults when no user config exists" {
    # Ensure no user config exists
    rm -f "${HOME}/.config/kimi-mcp/config.json"
    
    # Clear any env vars
    unset KIMI_MCP_MODEL
    unset KIMI_MCP_TIMEOUT
    unset KIMI_MCP_MAX_FILE_SIZE
    
    # Load config
    run mcp_config_load
    [ "$status" -eq 0 ]
    
    # Verify defaults
    [ "$MCP_CONFIG_MODEL" = "k2" ]
    [ "$MCP_CONFIG_TIMEOUT" = "30" ]
    [ "$MCP_CONFIG_MAX_FILE_SIZE" = "1048576" ]
}

@test "mcp_config_model returns default value" {
    rm -f "${HOME}/.config/kimi-mcp/config.json"
    unset KIMI_MCP_MODEL
    
    mcp_config_load
    
    run mcp_config_model
    [ "$output" = "k2" ]
}

@test "mcp_config_timeout returns default value" {
    rm -f "${HOME}/.config/kimi-mcp/config.json"
    unset KIMI_MCP_TIMEOUT
    
    mcp_config_load
    
    run mcp_config_timeout
    [ "$output" = "30" ]
}

@test "mcp_config_max_file_size returns default value" {
    rm -f "${HOME}/.config/kimi-mcp/config.json"
    unset KIMI_MCP_MAX_FILE_SIZE
    
    mcp_config_load
    
    run mcp_config_max_file_size
    [ "$output" = "1048576" ]
}

# ============================================================================
# Test: User config file override
# ============================================================================

@test "config loads user config values over defaults" {
    # Create user config with different values
    cat > "${HOME}/.config/kimi-mcp/config.json" <<'EOF'
{
  "model": "k2.5",
  "timeout": 60,
  "max_file_size": 2097152
}
EOF
    
    unset KIMI_MCP_MODEL
    unset KIMI_MCP_TIMEOUT
    unset KIMI_MCP_MAX_FILE_SIZE
    
    mcp_config_load
    
    [ "$MCP_CONFIG_MODEL" = "k2.5" ]
    [ "$MCP_CONFIG_TIMEOUT" = "60" ]
    [ "$MCP_CONFIG_MAX_FILE_SIZE" = "2097152" ]
}

@test "partial user config only overrides specified values" {
    # Create user config with only model specified
    cat > "${HOME}/.config/kimi-mcp/config.json" <<'EOF'
{
  "model": "k2.5"
}
EOF
    
    unset KIMI_MCP_MODEL
    unset KIMI_MCP_TIMEOUT
    unset KIMI_MCP_MAX_FILE_SIZE
    
    mcp_config_load
    
    [ "$MCP_CONFIG_MODEL" = "k2.5" ]
    [ "$MCP_CONFIG_TIMEOUT" = "30" ]  # Default
    [ "$MCP_CONFIG_MAX_FILE_SIZE" = "1048576" ]  # Default
}

# ============================================================================
# Test: Environment variable override
# ============================================================================

@test "KIMI_MCP_MODEL overrides all other sources" {
    # Create user config
    cat > "${HOME}/.config/kimi-mcp/config.json" <<'EOF'
{
  "model": "k2.5"
}
EOF
    
    # Set env var to different value
    export KIMI_MCP_MODEL="k2"
    
    mcp_config_load
    
    [ "$MCP_CONFIG_MODEL" = "k2" ]
}

@test "KIMI_MCP_TIMEOUT overrides all other sources" {
    cat > "${HOME}/.config/kimi-mcp/config.json" <<'EOF'
{
  "timeout": 60
}
EOF
    
    export KIMI_MCP_TIMEOUT="120"
    
    mcp_config_load
    
    [ "$MCP_CONFIG_TIMEOUT" = "120" ]
}

@test "KIMI_MCP_MAX_FILE_SIZE overrides all other sources" {
    cat > "${HOME}/.config/kimi-mcp/config.json" <<'EOF'
{
  "max_file_size": 2097152
}
EOF
    
    export KIMI_MCP_MAX_FILE_SIZE="5242880"
    
    mcp_config_load
    
    [ "$MCP_CONFIG_MAX_FILE_SIZE" = "5242880" ]
}

# ============================================================================
# Test: Precedence (env > user config > defaults)
# ============================================================================

@test "full precedence chain: env > user config > defaults" {
    # Set up user config
    cat > "${HOME}/.config/kimi-mcp/config.json" <<'EOF'
{
  "model": "k2.5",
  "timeout": 60,
  "max_file_size": 2097152
}
EOF
    
    # Set only model via env
    export KIMI_MCP_MODEL="k2"
    unset KIMI_MCP_TIMEOUT
    unset KIMI_MCP_MAX_FILE_SIZE
    
    mcp_config_load
    
    # Env should win for model
    [ "$MCP_CONFIG_MODEL" = "k2" ]
    # User config should win for others
    [ "$MCP_CONFIG_TIMEOUT" = "60" ]
    [ "$MCP_CONFIG_MAX_FILE_SIZE" = "2097152" ]
}

# ============================================================================
# Test: mcp_config_get function
# ============================================================================

@test "mcp_config_get returns correct value for model" {
    rm -f "${HOME}/.config/kimi-mcp/config.json"
    unset KIMI_MCP_MODEL
    
    mcp_config_load
    
    run mcp_config_get "model"
    [ "$output" = "k2" ]
}

@test "mcp_config_get returns correct value for timeout" {
    rm -f "${HOME}/.config/kimi-mcp/config.json"
    unset KIMI_MCP_TIMEOUT
    
    mcp_config_load
    
    run mcp_config_get "timeout"
    [ "$output" = "30" ]
}

@test "mcp_config_get returns correct value for max_file_size" {
    rm -f "${HOME}/.config/kimi-mcp/config.json"
    unset KIMI_MCP_MAX_FILE_SIZE
    
    mcp_config_load
    
    run mcp_config_get "max_file_size"
    [ "$output" = "1048576" ]
}

@test "mcp_config_get fails for unknown key" {
    mcp_config_load
    
    run mcp_config_get "unknown_key"
    [ "$status" -eq 1 ]
}

# ============================================================================
# Test: mcp_config_role function
# ============================================================================

@test "mcp_config_role returns general role by default" {
    rm -f "${HOME}/.config/kimi-mcp/config.json"
    
    mcp_config_load
    
    run mcp_config_role
    [[ "$output" == *"helpful coding assistant"* ]]
}

@test "mcp_config_role returns general role when explicitly requested" {
    mcp_config_load
    
    run mcp_config_role "general"
    [[ "$output" == *"helpful coding assistant"* ]]
}

@test "mcp_config_role returns security role" {
    mcp_config_load
    
    run mcp_config_role "security"
    [[ "$output" == *"security-focused"* ]]
}

@test "mcp_config_role returns performance role" {
    mcp_config_load
    
    run mcp_config_role "performance"
    [[ "$output" == *"performance optimization"* ]]
}

@test "mcp_config_role returns refactor role" {
    mcp_config_load
    
    run mcp_config_role "refactor"
    [[ "$output" == *"refactoring expert"* ]]
}

@test "mcp_config_role falls back to general for unknown role" {
    mcp_config_load
    
    run mcp_config_role "unknown_role"
    [ "$status" -eq 0 ]
    [[ "$output" == *"helpful coding assistant"* ]]
}

@test "mcp_config_role uses user config roles when available" {
    cat > "${HOME}/.config/kimi-mcp/config.json" <<'EOF'
{
  "roles": {
    "general": "Custom general prompt",
    "custom": "A custom role prompt"
  }
}
EOF
    
    mcp_config_load
    
    run mcp_config_role "general"
    [ "$output" = "Custom general prompt" ]
    
    run mcp_config_role "custom"
    [ "$output" = "A custom role prompt" ]
}

# ============================================================================
# Test: Validation
# ============================================================================

@test "invalid model value defaults to k2" {
    export KIMI_MCP_MODEL="invalid_model"
    
    mcp_config_load
    
    [ "$MCP_CONFIG_MODEL" = "k2" ]
}

@test "invalid timeout value defaults to 30" {
    export KIMI_MCP_TIMEOUT="not_a_number"
    
    mcp_config_load
    
    [ "$MCP_CONFIG_TIMEOUT" = "30" ]
}

@test "zero timeout defaults to 30" {
    export KIMI_MCP_TIMEOUT="0"
    
    mcp_config_load
    
    [ "$MCP_CONFIG_TIMEOUT" = "30" ]
}

@test "negative timeout defaults to 30" {
    export KIMI_MCP_TIMEOUT="-10"
    
    mcp_config_load
    
    [ "$MCP_CONFIG_TIMEOUT" = "30" ]
}

@test "invalid max_file_size defaults to 1048576" {
    export KIMI_MCP_MAX_FILE_SIZE="invalid"
    
    mcp_config_load
    
    [ "$MCP_CONFIG_MAX_FILE_SIZE" = "1048576" ]
}

# ============================================================================
# Test: Error handling
# ============================================================================

@test "mcp_config_load fails if default config missing" {
    # Temporarily move default config
    mv "${MCP_BRIDGE_ROOT}/config/default.json" "${MCP_BRIDGE_ROOT}/config/default.json.bak"
    
    run mcp_config_load
    [ "$status" -eq 1 ]
    
    # Restore default config
    mv "${MCP_BRIDGE_ROOT}/config/default.json.bak" "${MCP_BRIDGE_ROOT}/config/default.json"
}

@test "missing user config is handled gracefully" {
    rm -f "${HOME}/.config/kimi-mcp/config.json"
    
    run mcp_config_load
    [ "$status" -eq 0 ]
}

# ============================================================================
# Test: Utility functions
# ============================================================================

@test "mcp_config_ensure_dir creates config directory" {
    rm -rf "${HOME}/.config/kimi-mcp"
    
    [ ! -d "${HOME}/.config/kimi-mcp" ]
    
    mcp_config_ensure_dir
    
    [ -d "${HOME}/.config/kimi-mcp" ]
}

@test "mcp_config_export_template creates user config file" {
    rm -f "${HOME}/.config/kimi-mcp/config.json"
    
    mcp_config_load
    mcp_config_export_template
    
    [ -f "${HOME}/.config/kimi-mcp/config.json" ]
    
    # Verify it contains current values
    grep -q "\"model\": \"k2\"" "${HOME}/.config/kimi-mcp/config.json"
    grep -q "\"timeout\": 30" "${HOME}/.config/kimi-mcp/config.json"
}
