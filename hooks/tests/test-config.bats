#!/usr/bin/env bats
#
# Tests for Hooks Configuration Management
#
# Run with: bats test-config.bats

setup() {
    # Save original environment
    ORIGINAL_HOME="$HOME"
    ORIGINAL_HOOKS_ROOT="${HOOKS_ROOT:-}"
    ORIGINAL_KIMI_HOOKS_TIMEOUT="${KIMI_HOOKS_TIMEOUT:-}"
    ORIGINAL_KIMI_HOOKS_AUTO_FIX="${KIMI_HOOKS_AUTO_FIX:-}"
    ORIGINAL_KIMI_HOOKS_DRY_RUN="${KIMI_HOOKS_DRY_RUN:-}"
    ORIGINAL_KIMI_HOOKS_ENABLED_HOOKS="${KIMI_HOOKS_ENABLED_HOOKS:-}"
    ORIGINAL_KIMI_HOOKS_SKIP="${KIMI_HOOKS_SKIP:-}"
    
    # Set up test environment
    export HOOKS_ROOT="${BATS_TEST_DIRNAME}/.."
    export HOME="${BATS_TEST_TMPDIR}/home"
    mkdir -p "$HOME/.config/kimi"
    
    # Create a mock git root
    export KIMI_HOOKS_PROJECT_ROOT="${BATS_TEST_TMPDIR}/project"
    mkdir -p "$KIMI_HOOKS_PROJECT_ROOT/.kimi"
    
    # Source the config library
    source "${HOOKS_ROOT}/lib/hooks-config.sh"
}

teardown() {
    # Restore original environment
    export HOME="$ORIGINAL_HOME"
    if [[ -n "$ORIGINAL_HOOKS_ROOT" ]]; then
        export HOOKS_ROOT="$ORIGINAL_HOOKS_ROOT"
    else
        unset HOOKS_ROOT
    fi
    if [[ -n "$ORIGINAL_KIMI_HOOKS_TIMEOUT" ]]; then
        export KIMI_HOOKS_TIMEOUT="$ORIGINAL_KIMI_HOOKS_TIMEOUT"
    else
        unset KIMI_HOOKS_TIMEOUT
    fi
    if [[ -n "$ORIGINAL_KIMI_HOOKS_AUTO_FIX" ]]; then
        export KIMI_HOOKS_AUTO_FIX="$ORIGINAL_KIMI_HOOKS_AUTO_FIX"
    else
        unset KIMI_HOOKS_AUTO_FIX
    fi
    if [[ -n "$ORIGINAL_KIMI_HOOKS_DRY_RUN" ]]; then
        export KIMI_HOOKS_DRY_RUN="$ORIGINAL_KIMI_HOOKS_DRY_RUN"
    else
        unset KIMI_HOOKS_DRY_RUN
    fi
    if [[ -n "$ORIGINAL_KIMI_HOOKS_ENABLED_HOOKS" ]]; then
        export KIMI_HOOKS_ENABLED_HOOKS="$ORIGINAL_KIMI_HOOKS_ENABLED_HOOKS"
    else
        unset KIMI_HOOKS_ENABLED_HOOKS
    fi
    if [[ -n "$ORIGINAL_KIMI_HOOKS_SKIP" ]]; then
        export KIMI_HOOKS_SKIP="$ORIGINAL_KIMI_HOOKS_SKIP"
    else
        unset KIMI_HOOKS_SKIP
    fi
    unset KIMI_HOOKS_PROJECT_ROOT
}

# ============================================================================
# Test: Load defaults when no user config exists
# ============================================================================

@test "config loads defaults when no user config exists" {
    # Ensure no user config exists
    rm -f "${HOME}/.config/kimi/hooks.json"
    rm -f "${KIMI_HOOKS_PROJECT_ROOT}/.kimi/hooks.json"
    
    # Clear any env vars
    unset KIMI_HOOKS_TIMEOUT
    unset KIMI_HOOKS_AUTO_FIX
    unset KIMI_HOOKS_DRY_RUN
    unset KIMI_HOOKS_ENABLED_HOOKS
    
    # Load config
    run hooks_config_load
    [ "$status" -eq 0 ]
    
    # Verify defaults
    [ "$HOOKS_CONFIG_VERSION" = "1.0" ]
    [ "$HOOKS_CONFIG_TIMEOUT" = "60" ]
    [ "$HOOKS_CONFIG_AUTO_FIX" = "false" ]
    [ "$HOOKS_CONFIG_DRY_RUN" = "false" ]
    [ "$HOOKS_CONFIG_BYPASS_ENV_VAR" = "KIMI_HOOKS_SKIP" ]
}

@test "hooks_config_get returns default timeout" {
    rm -f "${HOME}/.config/kimi/hooks.json"
    unset KIMI_HOOKS_TIMEOUT
    
    hooks_config_load
    
    run hooks_config_get "timeout_seconds"
    [ "$output" = "60" ]
}

@test "hooks_config_get returns default auto_fix" {
    rm -f "${HOME}/.config/kimi/hooks.json"
    unset KIMI_HOOKS_AUTO_FIX
    
    hooks_config_load
    
    run hooks_config_get "auto_fix"
    [ "$output" = "false" ]
}

@test "hooks_config_is_dry_run returns default false" {
    rm -f "${HOME}/.config/kimi/hooks.json"
    unset KIMI_HOOKS_DRY_RUN
    
    hooks_config_load
    
    run hooks_config_is_dry_run
    [ "$output" = "false" ]
}

# ============================================================================
# Test: User config file override
# ============================================================================

@test "config loads user config values over defaults" {
    # Create user config with different values
    cat > "${HOME}/.config/kimi/hooks.json" <<'EOF'
{
  "timeout_seconds": 120,
  "auto_fix": true,
  "dry_run": true
}
EOF
    
    rm -f "${KIMI_HOOKS_PROJECT_ROOT}/.kimi/hooks.json"
    unset KIMI_HOOKS_TIMEOUT
    unset KIMI_HOOKS_AUTO_FIX
    unset KIMI_HOOKS_DRY_RUN
    
    hooks_config_load
    
    [ "$HOOKS_CONFIG_TIMEOUT" = "120" ]
    [ "$HOOKS_CONFIG_AUTO_FIX" = "true" ]
    [ "$HOOKS_CONFIG_DRY_RUN" = "true" ]
}

@test "partial user config only overrides specified values" {
    # Create user config with only timeout specified
    cat > "${HOME}/.config/kimi/hooks.json" <<'EOF'
{
  "timeout_seconds": 90
}
EOF
    
    rm -f "${KIMI_HOOKS_PROJECT_ROOT}/.kimi/hooks.json"
    unset KIMI_HOOKS_TIMEOUT
    unset KIMI_HOOKS_AUTO_FIX
    unset KIMI_HOOKS_DRY_RUN
    
    hooks_config_load
    
    [ "$HOOKS_CONFIG_TIMEOUT" = "90" ]
    [ "$HOOKS_CONFIG_AUTO_FIX" = "false" ]  # Default
    [ "$HOOKS_CONFIG_DRY_RUN" = "false" ]   # Default
}

# ============================================================================
# Test: Project config file override
# ============================================================================

@test "config loads project config values over user config" {
    # Create user config
    cat > "${HOME}/.config/kimi/hooks.json" <<'EOF'
{
  "timeout_seconds": 120,
  "auto_fix": true
}
EOF
    
    # Create project config with different values
    cat > "${KIMI_HOOKS_PROJECT_ROOT}/.kimi/hooks.json" <<'EOF'
{
  "timeout_seconds": 30,
  "dry_run": true
}
EOF
    
    unset KIMI_HOOKS_TIMEOUT
    unset KIMI_HOOKS_AUTO_FIX
    unset KIMI_HOOKS_DRY_RUN
    
    hooks_config_load
    
    # Project config should win for timeout
    [ "$HOOKS_CONFIG_TIMEOUT" = "30" ]
    # User config should still apply for auto_fix
    [ "$HOOKS_CONFIG_AUTO_FIX" = "true" ]
    # Project config should win for dry_run
    [ "$HOOKS_CONFIG_DRY_RUN" = "true" ]
}

@test "project config overrides user config for hooks" {
    # Create user config with hook settings
    cat > "${HOME}/.config/kimi/hooks.json" <<'EOF'
{
  "hooks": {
    "pre-commit": {
      "enabled": true,
      "auto_fix": true
    }
  }
}
EOF
    
    # Create project config with different hook settings
    cat > "${KIMI_HOOKS_PROJECT_ROOT}/.kimi/hooks.json" <<'EOF'
{
  "hooks": {
    "pre-commit": {
      "enabled": false,
      "max_files": 10
    }
  }
}
EOF
    
    hooks_config_load
    
    # Project config should override enabled
    run hooks_config_is_enabled "pre-commit"
    [ "$status" -eq 1 ]  # Disabled
    
    # Project config should provide max_files
    run hooks_config_get "hooks.pre-commit.max_files"
    [ "$output" = "10" ]
    
    # User config auto_fix should still be present (merged)
    run hooks_config_get "hooks.pre-commit.auto_fix"
    [ "$output" = "true" ]
}

# ============================================================================
# Test: Environment variable override
# ============================================================================

@test "KIMI_HOOKS_TIMEOUT overrides all other sources" {
    # Create user config
    cat > "${HOME}/.config/kimi/hooks.json" <<'EOF'
{
  "timeout_seconds": 120
}
EOF
    
    # Create project config
    cat > "${KIMI_HOOKS_PROJECT_ROOT}/.kimi/hooks.json" <<'EOF'
{
  "timeout_seconds": 90
}
EOF
    
    # Set env var to different value
    export KIMI_HOOKS_TIMEOUT="45"
    
    hooks_config_load
    
    [ "$HOOKS_CONFIG_TIMEOUT" = "45" ]
}

@test "KIMI_HOOKS_AUTO_FIX overrides all other sources" {
    cat > "${HOME}/.config/kimi/hooks.json" <<'EOF'
{
  "auto_fix": false
}
EOF
    
    export KIMI_HOOKS_AUTO_FIX="true"
    
    hooks_config_load
    
    [ "$HOOKS_CONFIG_AUTO_FIX" = "true" ]
}

@test "KIMI_HOOKS_DRY_RUN overrides all other sources" {
    cat > "${HOME}/.config/kimi/hooks.json" <<'EOF'
{
  "dry_run": false
}
EOF
    
    export KIMI_HOOKS_DRY_RUN="true"
    
    hooks_config_load
    
    [ "$HOOKS_CONFIG_DRY_RUN" = "true" ]
}

@test "KIMI_HOOKS_ENABLED_HOOKS overrides all other sources" {
    cat > "${HOME}/.config/kimi/hooks.json" <<'EOF'
{
  "enabled_hooks": ["pre-commit", "pre-push"]
}
EOF
    
    export KIMI_HOOKS_ENABLED_HOOKS='"pre-commit"'
    
    hooks_config_load
    
    run hooks_config_is_enabled "pre-commit"
    [ "$status" -eq 0 ]
    
    run hooks_config_is_enabled "pre-push"
    [ "$status" -eq 1 ]  # Not in env override
}

# ============================================================================
# Test: Precedence (env > project > user > defaults)
# ============================================================================

@test "full precedence chain: env > project > user > defaults" {
    # Set up user config
    cat > "${HOME}/.config/kimi/hooks.json" <<'EOF'
{
  "timeout_seconds": 120,
  "auto_fix": true,
  "dry_run": false
}
EOF
    
    # Set up project config
    cat > "${KIMI_HOOKS_PROJECT_ROOT}/.kimi/hooks.json" <<'EOF'
{
  "timeout_seconds": 90,
  "dry_run": true
}
EOF
    
    # Set only timeout via env
    export KIMI_HOOKS_TIMEOUT="45"
    unset KIMI_HOOKS_AUTO_FIX
    unset KIMI_HOOKS_DRY_RUN
    
    hooks_config_load
    
    # Env should win for timeout
    [ "$HOOKS_CONFIG_TIMEOUT" = "45" ]
    # User config should win for auto_fix (not in project or env)
    [ "$HOOKS_CONFIG_AUTO_FIX" = "true" ]
    # Project config should win for dry_run
    [ "$HOOKS_CONFIG_DRY_RUN" = "true" ]
}

# ============================================================================
# Test: hooks_config_is_enabled function
# ============================================================================

@test "hooks_config_is_enabled returns true for enabled hook" {
    rm -f "${HOME}/.config/kimi/hooks.json"
    rm -f "${KIMI_HOOKS_PROJECT_ROOT}/.kimi/hooks.json"
    unset KIMI_HOOKS_ENABLED_HOOKS
    
    hooks_config_load
    
    run hooks_config_is_enabled "pre-commit"
    [ "$status" -eq 0 ]
}

@test "hooks_config_is_enabled returns false for disabled hook" {
    cat > "${HOME}/.config/kimi/hooks.json" <<'EOF'
{
  "enabled_hooks": ["pre-push"]
}
EOF
    
    rm -f "${KIMI_HOOKS_PROJECT_ROOT}/.kimi/hooks.json"
    unset KIMI_HOOKS_ENABLED_HOOKS
    
    hooks_config_load
    
    run hooks_config_is_enabled "pre-commit"
    [ "$status" -eq 1 ]
}

@test "hooks_config_is_enabled respects hook-specific enabled setting" {
    cat > "${HOME}/.config/kimi/hooks.json" <<'EOF'
{
  "enabled_hooks": ["pre-commit", "pre-push"],
  "hooks": {
    "pre-commit": {
      "enabled": false
    }
  }
}
EOF
    
    rm -f "${KIMI_HOOKS_PROJECT_ROOT}/.kimi/hooks.json"
    unset KIMI_HOOKS_ENABLED_HOOKS
    
    hooks_config_load
    
    # Should be disabled even though in enabled_hooks list
    run hooks_config_is_enabled "pre-commit"
    [ "$status" -eq 1 ]
    
    # pre-push should still be enabled
    run hooks_config_is_enabled "pre-push"
    [ "$status" -eq 0 ]
}

# ============================================================================
# Test: hooks_config_get for nested values
# ============================================================================

@test "hooks_config_get returns nested hook value" {
    rm -f "${HOME}/.config/kimi/hooks.json"
    rm -f "${KIMI_HOOKS_PROJECT_ROOT}/.kimi/hooks.json"
    
    hooks_config_load
    
    run hooks_config_get "hooks.pre-commit.max_files"
    [ "$output" = "50" ]
}

@test "hooks_config_get returns nested hook check_types" {
    rm -f "${HOME}/.config/kimi/hooks.json"
    rm -f "${KIMI_HOOKS_PROJECT_ROOT}/.kimi/hooks.json"
    
    hooks_config_load
    
    run hooks_config_get "hooks.pre-commit.check_types"
    [[ "$output" == *"lint"* ]]
    [[ "$output" == *"format"* ]]
}

@test "hooks_config_get returns empty for missing nested value" {
    rm -f "${HOME}/.config/kimi/hooks.json"
    rm -f "${KIMI_HOOKS_PROJECT_ROOT}/.kimi/hooks.json"
    
    hooks_config_load
    
    run hooks_config_get "hooks.pre-commit.nonexistent"
    [ -z "$output" ]
}

@test "hooks_config_get fails for unknown key" {
    hooks_config_load
    
    run hooks_config_get "unknown_key"
    [ "$status" -eq 1 ]
}

# ============================================================================
# Test: Hook-specific settings override global
# ============================================================================

@test "hooks_config_timeout returns hook-specific value" {
    cat > "${HOME}/.config/kimi/hooks.json" <<'EOF'
{
  "timeout_seconds": 60,
  "hooks": {
    "pre-push": {
      "timeout_seconds": 180
    }
  }
}
EOF
    
    rm -f "${KIMI_HOOKS_PROJECT_ROOT}/.kimi/hooks.json"
    
    hooks_config_load
    
    # Global timeout
    run hooks_config_timeout
    [ "$output" = "60" ]
    
    # Hook-specific timeout
    run hooks_config_timeout "pre-push"
    [ "$output" = "180" ]
    
    # Other hooks use global
    run hooks_config_timeout "pre-commit"
    [ "$output" = "60" ]
}

@test "hooks_config_auto_fix returns hook-specific value" {
    cat > "${HOME}/.config/kimi/hooks.json" <<'EOF'
{
  "auto_fix": false,
  "hooks": {
    "pre-commit": {
      "auto_fix": true
    }
  }
}
EOF
    
    rm -f "${KIMI_HOOKS_PROJECT_ROOT}/.kimi/hooks.json"
    
    hooks_config_load
    
    # Global auto_fix
    run hooks_config_auto_fix
    [ "$output" = "false" ]
    
    # Hook-specific auto_fix
    run hooks_config_auto_fix "pre-commit"
    [ "$output" = "true" ]
    
    # Other hooks use global
    run hooks_config_auto_fix "pre-push"
    [ "$output" = "false" ]
}

# ============================================================================
# Test: Bypass mechanism
# ============================================================================

@test "hooks_config_should_bypass returns false when bypass var not set" {
    rm -f "${HOME}/.config/kimi/hooks.json"
    unset KIMI_HOOKS_SKIP
    
    hooks_config_load
    
    run hooks_config_should_bypass
    [ "$status" -eq 1 ]
}

@test "hooks_config_should_bypass returns true when bypass var is set" {
    rm -f "${HOME}/.config/kimi/hooks.json"
    export KIMI_HOOKS_SKIP="1"
    
    hooks_config_load
    
    run hooks_config_should_bypass
    [ "$status" -eq 0 ]
}

@test "hooks_config_should_bypass respects custom bypass env var" {
    cat > "${HOME}/.config/kimi/hooks.json" <<'EOF'
{
  "bypass_env_var": "MY_CUSTOM_SKIP"
}
EOF
    
    unset KIMI_HOOKS_SKIP
    export MY_CUSTOM_SKIP="yes"
    
    hooks_config_load
    
    run hooks_config_should_bypass
    [ "$status" -eq 0 ]
}

@test "hooks_config_should_bypass returns false for zero value" {
    rm -f "${HOME}/.config/kimi/hooks.json"
    export KIMI_HOOKS_SKIP="0"
    
    hooks_config_load
    
    run hooks_config_should_bypass
    [ "$status" -eq 1 ]
}

@test "hooks_config_should_bypass returns false for false value" {
    rm -f "${HOME}/.config/kimi/hooks.json"
    export KIMI_HOOKS_SKIP="false"
    
    hooks_config_load
    
    run hooks_config_should_bypass
    [ "$status" -eq 1 ]
}

# ============================================================================
# Test: Validation
# ============================================================================

@test "invalid timeout value defaults to 60" {
    export KIMI_HOOKS_TIMEOUT="not_a_number"
    
    hooks_config_load
    
    [ "$HOOKS_CONFIG_TIMEOUT" = "60" ]
}

@test "zero timeout defaults to 60" {
    export KIMI_HOOKS_TIMEOUT="0"
    
    hooks_config_load
    
    [ "$HOOKS_CONFIG_TIMEOUT" = "60" ]
}

@test "negative timeout defaults to 60" {
    export KIMI_HOOKS_TIMEOUT="-10"
    
    hooks_config_load
    
    [ "$HOOKS_CONFIG_TIMEOUT" = "60" ]
}

@test "invalid auto_fix value defaults to false" {
    export KIMI_HOOKS_AUTO_FIX="invalid"
    
    hooks_config_load
    
    [ "$HOOKS_CONFIG_AUTO_FIX" = "false" ]
}

@test "invalid dry_run value defaults to false" {
    export KIMI_HOOKS_DRY_RUN="invalid"
    
    hooks_config_load
    
    [ "$HOOKS_CONFIG_DRY_RUN" = "false" ]
}

# ============================================================================
# Test: Error handling
# ============================================================================

@test "hooks_config_load fails if default config missing" {
    # Temporarily move default config
    mv "${HOOKS_ROOT}/config/default.json" "${HOOKS_ROOT}/config/default.json.bak"
    
    run hooks_config_load
    [ "$status" -eq 1 ]
    
    # Restore default config
    mv "${HOOKS_ROOT}/config/default.json.bak" "${HOOKS_ROOT}/config/default.json"
}

@test "missing user config is handled gracefully" {
    rm -f "${HOME}/.config/kimi/hooks.json"
    rm -f "${KIMI_HOOKS_PROJECT_ROOT}/.kimi/hooks.json"
    
    run hooks_config_load
    [ "$status" -eq 0 ]
}

@test "missing project config is handled gracefully" {
    rm -f "${HOME}/.config/kimi/hooks.json"
    rm -f "${KIMI_HOOKS_PROJECT_ROOT}/.kimi/hooks.json"
    
    run hooks_config_load
    [ "$status" -eq 0 ]
}

# ============================================================================
# Test: Utility functions
# ============================================================================

@test "hooks_config_ensure_dir creates config directory" {
    rm -rf "${HOME}/.config/kimi"
    
    [ ! -d "${HOME}/.config/kimi" ]
    
    hooks_config_ensure_dir
    
    [ -d "${HOME}/.config/kimi" ]
}

@test "hooks_config_export_template creates user config file" {
    rm -f "${HOME}/.config/kimi/hooks.json"
    
    hooks_config_load
    hooks_config_export_template
    
    [ -f "${HOME}/.config/kimi/hooks.json" ]
    
    # Verify it contains current values
    grep -q '"version":' "${HOME}/.config/kimi/hooks.json"
    grep -q '"timeout_seconds":' "${HOME}/.config/kimi/hooks.json"
}

@test "hooks_config_has_jq returns appropriate status" {
    # Just verify the function exists and returns
    run hooks_config_has_jq
    # Result depends on whether jq is installed in test environment
    [ "$status" -eq 0 ] || [ "$status" -eq 1 ]
}

@test "hooks_config_list_enabled returns space-separated hook types" {
    rm -f "${HOME}/.config/kimi/hooks.json"
    rm -f "${KIMI_HOOKS_PROJECT_ROOT}/.kimi/hooks.json"
    unset KIMI_HOOKS_ENABLED_HOOKS
    
    hooks_config_load
    
    run hooks_config_list_enabled
    [[ "$output" == *"pre-commit"* ]]
    [[ "$output" == *"post-checkout"* ]]
    [[ "$output" == *"pre-push"* ]]
}

@test "hooks_config_file_patterns returns JSON array" {
    rm -f "${HOME}/.config/kimi/hooks.json"
    rm -f "${KIMI_HOOKS_PROJECT_ROOT}/.kimi/hooks.json"
    
    hooks_config_load
    
    run hooks_config_file_patterns
    [[ "$output" == \[* ]]  # Starts with [
    [[ "$output" == *\] ]]  # Ends with ]
    [[ "$output" == *"*.py"* ]]
    [[ "$output" == *"*.js"* ]]
}

# ============================================================================
# Test: File patterns
# ============================================================================

@test "file_patterns can be overridden via environment" {
    export KIMI_HOOKS_FILE_PATTERNS='"*.rs", "*.go"'
    
    hooks_config_load
    
    run hooks_config_file_patterns
    [[ "$output" == *"*.rs"* ]]
    [[ "$output" == *"*.go"* ]]
    [[ "$output" != *"*.py"* ]]
}
