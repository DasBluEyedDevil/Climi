#!/bin/bash
#
# MCP Tool Handlers for Kimi MCP Server
#
# Purpose: Implements the 4 MCP tool handlers (kimi_analyze, kimi_implement,
#          kimi_refactor, kimi_verify) plus tool definitions for MCP protocol.
#
# Dependencies:
#   - mcp-core.sh (must be sourced before this file)
#   - config.sh (must be sourced before this file)
#   - file-reader.sh (must be sourced before this file)
#   - jq (for JSON parsing)
#   - kimi CLI (for tool execution)
#
# Usage:
#   source mcp-bridge/lib/mcp-core.sh
#   source mcp-bridge/lib/config.sh
#   source mcp-bridge/lib/file-reader.sh
#   source mcp-bridge/lib/mcp-tools.sh
#
#   # Get tool definitions
#   defs=$(mcp_get_tool_definitions)
#
#   # Handle tool calls
#   mcp_tool_analyze '{"prompt": "analyze this"}' "request-id"

# Ensure dependencies are loaded
if ! declare -f mcp_send_response >/dev/null 2>&1; then
    echo "Error: mcp-core.sh must be sourced before mcp-tools.sh" >&2
    exit 1
fi

if ! declare -f mcp_config_model >/dev/null 2>&1; then
    echo "Error: config.sh must be sourced before mcp-tools.sh" >&2
    exit 1
fi

if ! declare -f mcp_read_files >/dev/null 2>&1; then
    echo "Error: file-reader.sh must be sourced before mcp-tools.sh" >&2
    exit 1
fi

# ============================================================================
# Tool Definitions
# ============================================================================

# Get JSON array of tool definitions per MCP spec
#
# Output:
#   JSON object with "tools" array containing all 4 tool definitions
#
# Example:
#   defs=$(mcp_get_tool_definitions)
#   echo "$defs" | jq '.tools | length'  # outputs: 4
mcp_get_tool_definitions() {
    jq -n '{
        tools: [
            {
                name: "kimi_analyze",
                title: "Analyze code with Kimi",
                description: "Analyze code, files, or text using Kimi K2.5 with a specified analysis role.",
                inputSchema: {
                    type: "object",
                    properties: {
                        prompt: {
                            type: "string",
                            description: "The analysis prompt or question"
                        },
                        files: {
                            type: "array",
                            items: { type: "string" },
                            description: "Optional file paths to include in analysis"
                        },
                        context: {
                            type: "string",
                            description: "Optional additional context"
                        },
                        role: {
                            type: "string",
                            description: "Analysis role (e.g., security, performance)",
                            default: "general"
                        },
                        auto_model: {
                            type: "boolean",
                            description: "Enable automatic model selection (K2 for routine, K2.5 for creative)",
                            default: false
                        }
                    },
                    required: ["prompt"]
                }
            },
            {
                name: "kimi_implement",
                title: "Implement with Kimi",
                description: "Implement features or fixes autonomously using Kimi K2.5.",
                inputSchema: {
                    type: "object",
                    properties: {
                        prompt: {
                            type: "string",
                            description: "The implementation request"
                        },
                        files: {
                            type: "array",
                            items: { type: "string" },
                            description: "Optional file paths for context"
                        },
                        constraints: {
                            type: "string",
                            description: "Optional implementation constraints"
                        },
                        auto_model: {
                            type: "boolean",
                            description: "Enable automatic model selection (K2 for routine, K2.5 for creative)",
                            default: false
                        }
                    },
                    required: ["prompt"]
                }
            },
            {
                name: "kimi_refactor",
                title: "Refactor with Kimi",
                description: "Refactor code with safety checks using Kimi K2.5.",
                inputSchema: {
                    type: "object",
                    properties: {
                        prompt: {
                            type: "string",
                            description: "The refactoring request"
                        },
                        files: {
                            type: "array",
                            items: { type: "string" },
                            description: "Files to refactor"
                        },
                        safety_checks: {
                            type: "boolean",
                            description: "Enable safety checks",
                            default: true
                        },
                        auto_model: {
                            type: "boolean",
                            description: "Enable automatic model selection (K2 for routine, K2.5 for creative)",
                            default: false
                        }
                    },
                    required: ["prompt"]
                }
            },
            {
                name: "kimi_verify",
                title: "Verify with Kimi",
                description: "Verify changes against requirements using Kimi K2.5.",
                inputSchema: {
                    type: "object",
                    properties: {
                        prompt: {
                            type: "string",
                            description: "Verification criteria"
                        },
                        files: {
                            type: "array",
                            items: { type: "string" },
                            description: "Files to verify"
                        },
                        requirements: {
                            type: "string",
                            description: "Requirements to verify against"
                        },
                        auto_model: {
                            type: "boolean",
                            description: "Enable automatic model selection (K2 for routine, K2.5 for creative)",
                            default: false
                        }
                    },
                    required: ["prompt"]
                }
            }
        ]
    }'
}

# ============================================================================
# Tool Handlers
# ============================================================================

# Handle kimi_analyze tool call
#
# Arguments:
#   $1 - Tool arguments as JSON string
#   $2 - Request ID
#
# Behavior:
#   - Extracts prompt (required), files, context, role
#   - Builds full prompt with role system prompt and file contents
#   - Calls Kimi CLI with timeout
#   - Returns result via mcp_send_response
#
# Example:
#   mcp_tool_analyze '{"prompt": "analyze this code", "role": "security"}' "123"
mcp_tool_analyze() {
    local arguments="${1:-}"
    local id="${2:-}"

    # Extract parameters using jq
    local prompt
    prompt=$(echo "$arguments" | jq -r '.prompt // empty')
    local files
    files=$(echo "$arguments" | jq -r '.files // empty')
    local context
    context=$(echo "$arguments" | jq -r '.context // empty')
    local role
    role=$(echo "$arguments" | jq -r '.role // "general"')

    # Validate required parameter
    if [[ -z "$prompt" || "$prompt" == "null" ]]; then
        mcp_send_response "$id" "Missing required parameter: prompt" "true"
        return 1
    fi

    # Build full prompt
    local full_prompt=""

    # Add role system prompt
    local system_prompt
    system_prompt=$(mcp_config_role "$role")
    full_prompt="${system_prompt}

"

    # Add files if provided
    if [[ -n "$files" && "$files" != "null" && "$files" != "[]" ]]; then
        local max_size
        max_size=$(mcp_config_max_file_size)
        local file_contents
        file_contents=$(mcp_read_files "$files" "$max_size")
        if [[ -n "$file_contents" ]]; then
            full_prompt="${full_prompt}Context files:
${file_contents}
"
        fi
    fi

    # Add context if provided
    if [[ -n "$context" && "$context" != "null" ]]; then
        full_prompt="${full_prompt}Additional context: ${context}

"
    fi

    # Add main prompt
    full_prompt="${full_prompt}Task: ${prompt}"

    # Determine model: auto_model or static config
    local auto_model
    auto_model=$(echo "$arguments" | jq -r '.auto_model // false')

    local model
    if [[ "$auto_model" == "true" ]]; then
        model=$(mcp_select_model "$prompt" "$files")
    else
        model=$(mcp_config_model)
    fi

    local timeout
    timeout=$(mcp_config_timeout)

    local result
    local exit_code

    result=$(mcp_call_kimi "$full_prompt" "$model" "$timeout")
    exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        mcp_send_response "$id" "$result" "false"
    else
        mcp_send_response "$id" "Kimi CLI failed with exit code $exit_code: $result" "true"
    fi
}

# Handle kimi_implement tool call
#
# Arguments:
#   $1 - Tool arguments as JSON string
#   $2 - Request ID
#
# Behavior:
#   - Extracts prompt (required), files, constraints
#   - Builds implementation prompt with system message
#   - Calls Kimi CLI with timeout
#   - Returns result via mcp_send_response
#
# Example:
#   mcp_tool_implement '{"prompt": "implement a function", "constraints": "use bash"}' "123"
mcp_tool_implement() {
    local arguments="${1:-}"
    local id="${2:-}"

    # Extract parameters using jq
    local prompt
    prompt=$(echo "$arguments" | jq -r '.prompt // empty')
    local files
    files=$(echo "$arguments" | jq -r '.files // empty')
    local constraints
    constraints=$(echo "$arguments" | jq -r '.constraints // empty')

    # Validate required parameter
    if [[ -z "$prompt" || "$prompt" == "null" ]]; then
        mcp_send_response "$id" "Missing required parameter: prompt" "true"
        return 1
    fi

    # Build full prompt
    local full_prompt="You are an expert software developer. Implement the requested feature or fix.

"

    # Add files if provided
    if [[ -n "$files" && "$files" != "null" && "$files" != "[]" ]]; then
        local max_size
        max_size=$(mcp_config_max_file_size)
        local file_contents
        file_contents=$(mcp_read_files "$files" "$max_size")
        if [[ -n "$file_contents" ]]; then
            full_prompt="${full_prompt}Context files:
${file_contents}
"
        fi
    fi

    # Add constraints if provided
    if [[ -n "$constraints" && "$constraints" != "null" ]]; then
        full_prompt="${full_prompt}Constraints: ${constraints}

"
    fi

    # Add main prompt
    full_prompt="${full_prompt}Implementation request: ${prompt}"

    # Determine model: auto_model or static config
    local auto_model
    auto_model=$(echo "$arguments" | jq -r '.auto_model // false')

    local model
    if [[ "$auto_model" == "true" ]]; then
        model=$(mcp_select_model "$prompt" "$files")
    else
        model=$(mcp_config_model)
    fi

    local timeout
    timeout=$(mcp_config_timeout)

    local result
    local exit_code

    result=$(mcp_call_kimi "$full_prompt" "$model" "$timeout")
    exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        mcp_send_response "$id" "$result" "false"
    else
        mcp_send_response "$id" "Kimi CLI failed with exit code $exit_code: $result" "true"
    fi
}

# Handle kimi_refactor tool call
#
# Arguments:
#   $1 - Tool arguments as JSON string
#   $2 - Request ID
#
# Behavior:
#   - Extracts prompt (required), files, safety_checks (default: true)
#   - Builds refactoring prompt with safety instructions
#   - Calls Kimi CLI with timeout
#   - Returns result via mcp_send_response
#
# Example:
#   mcp_tool_refactor '{"prompt": "refactor this function", "safety_checks": true}' "123"
mcp_tool_refactor() {
    local arguments="${1:-}"
    local id="${2:-}"

    # Extract parameters using jq
    local prompt
    prompt=$(echo "$arguments" | jq -r '.prompt // empty')
    local files
    files=$(echo "$arguments" | jq -r '.files // empty')
    local safety_checks
    safety_checks=$(echo "$arguments" | jq -r '.safety_checks // true')

    # Validate required parameter
    if [[ -z "$prompt" || "$prompt" == "null" ]]; then
        mcp_send_response "$id" "Missing required parameter: prompt" "true"
        return 1
    fi

    # Build full prompt
    local full_prompt="You are a refactoring expert. Improve code quality while preserving behavior.

"

    # Add safety checks instruction if enabled
    if [[ "$safety_checks" == "true" ]]; then
        full_prompt="${full_prompt}IMPORTANT: Ensure all safety checks pass. Do not change behavior.

"
    fi

    # Add files if provided
    if [[ -n "$files" && "$files" != "null" && "$files" != "[]" ]]; then
        local max_size
        max_size=$(mcp_config_max_file_size)
        local file_contents
        file_contents=$(mcp_read_files "$files" "$max_size")
        if [[ -n "$file_contents" ]]; then
            full_prompt="${full_prompt}Files to refactor:
${file_contents}
"
        fi
    fi

    # Add main prompt
    full_prompt="${full_prompt}Refactoring request: ${prompt}"

    # Determine model: auto_model or static config
    local auto_model
    auto_model=$(echo "$arguments" | jq -r '.auto_model // false')

    local model
    if [[ "$auto_model" == "true" ]]; then
        model=$(mcp_select_model "$prompt" "$files")
    else
        model=$(mcp_config_model)
    fi

    local timeout
    timeout=$(mcp_config_timeout)

    local result
    local exit_code

    result=$(mcp_call_kimi "$full_prompt" "$model" "$timeout")
    exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        mcp_send_response "$id" "$result" "false"
    else
        mcp_send_response "$id" "Kimi CLI failed with exit code $exit_code: $result" "true"
    fi
}

# Handle kimi_verify tool call
#
# Arguments:
#   $1 - Tool arguments as JSON string
#   $2 - Request ID
#
# Behavior:
#   - Extracts prompt (required), files, requirements
#   - Builds verification prompt with requirements
#   - Calls Kimi CLI with timeout
#   - Returns result via mcp_send_response
#
# Example:
#   mcp_tool_verify '{"prompt": "verify this implementation", "requirements": "must handle errors"}' "123"
mcp_tool_verify() {
    local arguments="${1:-}"
    local id="${2:-}"

    # Extract parameters using jq
    local prompt
    prompt=$(echo "$arguments" | jq -r '.prompt // empty')
    local files
    files=$(echo "$arguments" | jq -r '.files // empty')
    local requirements
    requirements=$(echo "$arguments" | jq -r '.requirements // empty')

    # Validate required parameter
    if [[ -z "$prompt" || "$prompt" == "null" ]]; then
        mcp_send_response "$id" "Missing required parameter: prompt" "true"
        return 1
    fi

    # Build full prompt
    local full_prompt="You are a verification expert. Check if implementation meets requirements.

"

    # Add requirements if provided
    if [[ -n "$requirements" && "$requirements" != "null" ]]; then
        full_prompt="${full_prompt}Requirements to verify:
${requirements}

"
    fi

    # Add files if provided
    if [[ -n "$files" && "$files" != "null" && "$files" != "[]" ]]; then
        local max_size
        max_size=$(mcp_config_max_file_size)
        local file_contents
        file_contents=$(mcp_read_files "$files" "$max_size")
        if [[ -n "$file_contents" ]]; then
            full_prompt="${full_prompt}Files to verify:
${file_contents}
"
        fi
    fi

    # Add main prompt
    full_prompt="${full_prompt}Verification criteria: ${prompt}"

    # Determine model: auto_model or static config
    local auto_model
    auto_model=$(echo "$arguments" | jq -r '.auto_model // false')

    local model
    if [[ "$auto_model" == "true" ]]; then
        model=$(mcp_select_model "$prompt" "$files")
    else
        model=$(mcp_config_model)
    fi

    local timeout
    timeout=$(mcp_config_timeout)

    local result
    local exit_code

    result=$(mcp_call_kimi "$full_prompt" "$model" "$timeout")
    exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        mcp_send_response "$id" "$result" "false"
    else
        mcp_send_response "$id" "Kimi CLI failed with exit code $exit_code: $result" "true"
    fi
}

# ============================================================================
# Helper Functions
# ============================================================================

# Call Kimi CLI with timeout
#
# Arguments:
#   $1 - Prompt to send to Kimi
#   $2 - Model to use (k2 or k2.5)
#   $3 - Timeout in seconds
#
# Output:
#   Kimi CLI output to stdout
#   Exit code from timeout command (0 on success, 124 on timeout)
#
# Example:
#   result=$(mcp_call_kimi "analyze this code" "k2" 30)
#   exit_code=$?
mcp_call_kimi() {
    local prompt="$1"
    local model="${2:-k2}"
    local timeout_sec="${3:-30}"

    # Validate model parameter
    if [[ "$model" != "k2" && "$model" != "k2.5" ]]; then
        echo "Error: Invalid model '$model'. Must be k2 or k2.5." >&2
        return 1
    fi

    # Check if kimi CLI is available
    if ! command -v kimi >/dev/null 2>&1; then
        echo "Error: kimi CLI not found in PATH" >&2
        return 1
    fi

    # Call kimi with timeout
    # Capture both stdout and stderr
    local output
    local exit_code

    # Set Python encoding for Windows compatibility (handles Unicode output from kimi)
    export PYTHONIOENCODING=utf-8

    # Use timeout command to enforce time limit
    # Exit code 124 means timeout occurred
    output=$(timeout "$timeout_sec" kimi -m "$model" "$prompt" 2>&1)
    exit_code=$?

    # Output the result
    echo "$output"
    return $exit_code
}

# ============================================================================
# Export Functions
# ============================================================================

export -f mcp_get_tool_definitions
export -f mcp_tool_analyze
export -f mcp_tool_implement
export -f mcp_tool_refactor
export -f mcp_tool_verify
export -f mcp_call_kimi
