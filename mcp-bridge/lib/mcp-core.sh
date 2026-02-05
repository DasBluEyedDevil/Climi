#!/bin/bash
# mcp-core.sh - Core MCP Protocol Handling
#
# Purpose: Provides core MCP protocol functions for JSON-RPC 2.0 message handling
#          including request parsing, response generation, and protocol initialization.
#
# Dependencies:
#   - mcp-errors.sh (must be sourced before this file)
#   - jq 1.6+ (for JSON parsing and generation)
#
# Protocol Version: 2025-11-25 (MCP Specification)
#
# Usage:
#   source mcp-bridge/lib/mcp-errors.sh
#   source mcp-bridge/lib/mcp-core.sh
#
#   # Parse a request
#   parsed=$(mcp_parse_request '{"jsonrpc":"2.0","id":"123","method":"test"}')
#   method=$(echo "$parsed" | jq -r '.method')
#
#   # Send a result
#   mcp_send_result "123" '"success"'

# Ensure mcp-errors.sh is loaded
if ! declare -f mcp_error_parse >/dev/null 2>&1; then
    echo "Error: mcp-errors.sh must be sourced before mcp-core.sh" >&2
    exit 1
fi

# Protocol version supported by this server
readonly MCP_PROTOCOL_VERSION="2025-11-25"
readonly MCP_SERVER_NAME="kimi-mcp-server"
readonly MCP_SERVER_VERSION="1.0.0"

# mcp_parse_request - Parse a JSON-RPC request line
#
# Arguments:
#   $1 - A single line containing a JSON-RPC request
#
# Output: JSON object with extracted fields (id, method, params)
#   {"id": "...", "method": "...", "params": {...}}
#
# Returns: Empty string if line is empty or invalid JSON
#
# Example:
#   result=$(mcp_parse_request '{"jsonrpc":"2.0","id":"123","method":"test","params":{"foo":"bar"}}')
#   echo "$result" | jq -r '.method'  # outputs: test
mcp_parse_request() {
    local line="${1:-}"
    
    # Return empty for empty input
    if [[ -z "$line" ]]; then
        echo "{}"
        return
    fi
    
    # Validate JSON and extract fields using jq
    # Returns empty if JSON is invalid
    echo "$line" | jq -c '{
        id: (.id // null),
        method: (.method // ""),
        params: (.params // {})
    }' 2>/dev/null || echo "{}"
}

# mcp_send_result - Send a successful JSON-RPC response
#
# Arguments:
#   $1 - Request ID (preserved from request)
#   $2 - Result value (already JSON string, can be any valid JSON)
#
# Output: Properly formatted JSON-RPC 2.0 response to stdout
#
# Example:
#   mcp_send_result "123" '"success message"'
#   mcp_send_result "456" '{"tools": []}'
mcp_send_result() {
    local id="${1:-}"
    local result="${2:-null}"
    
    # Use --argjson for result to preserve JSON structure
    jq -n \
        --arg id "$id" \
        --argjson result "$result" \
        '{
            jsonrpc: "2.0",
            id: (if $id == "" then null else $id end),
            result: $result
        }'
}

# mcp_send_response - Send a tool result response (MCP ToolResult format)
#
# Arguments:
#   $1 - Request ID
#   $2 - Text content to return
#   $3 - isError flag ("true" or "false", defaults to "false")
#
# Output: JSON-RPC response with result wrapped in MCP ToolResult format
#   {
#     "jsonrpc": "2.0",
#     "id": "...",
#     "result": {
#       "content": [{"type": "text", "text": "..."}],
#       "isError": false
#     }
#   }
#
# Example:
#   mcp_send_response "123" "Analysis complete" "false"
mcp_send_response() {
    local id="${1:-}"
    local content="${2:-}"
    local is_error="${3:-false}"
    
    # Convert is_error string to boolean for jq
    local is_error_bool="false"
    if [[ "$is_error" == "true" ]]; then
        is_error_bool="true"
    fi
    
    jq -n \
        --arg id "$id" \
        --arg content "$content" \
        --argjson is_error "$is_error_bool" \
        '{
            jsonrpc: "2.0",
            id: (if $id == "" then null else $id end),
            result: {
                content: [
                    {
                        type: "text",
                        text: $content
                    }
                ],
                isError: $is_error
            }
        }'
}

# mcp_send_initialize_result - Send InitializeResult for initialize method
#
# Arguments:
#   $1 - Request ID
#   $2 - Protocol version (optional, defaults to MCP_PROTOCOL_VERSION)
#
# Output: JSON-RPC InitializeResult response per MCP spec
#   {
#     "jsonrpc": "2.0",
#     "id": "...",
#     "result": {
#       "protocolVersion": "2025-11-25",
#       "capabilities": {
#         "tools": {"listChanged": false}
#       },
#       "serverInfo": {
#         "name": "kimi-mcp-server",
#         "version": "1.0.0"
#       }
#     }
#   }
#
# Example:
#   mcp_send_initialize_result "init-123"
mcp_send_initialize_result() {
    local id="${1:-}"
    local protocol_version="${2:-$MCP_PROTOCOL_VERSION}"
    
    jq -n \
        --arg id "$id" \
        --arg version "$protocol_version" \
        --arg name "$MCP_SERVER_NAME" \
        --arg server_version "$MCP_SERVER_VERSION" \
        '{
            jsonrpc: "2.0",
            id: (if $id == "" then null else $id end),
            result: {
                protocolVersion: $version,
                capabilities: {
                    tools: {
                        listChanged: false
                    }
                },
                serverInfo: {
                    name: $name,
                    version: $server_version
                }
            }
        }'
}

# mcp_send_tools_list - Send tools/list result
#
# Arguments:
#   $1 - Request ID
#   $2 - Tools array as JSON string (e.g., '[{"name": "tool1", ...}]')
#
# Output: JSON-RPC response with tools wrapped in {tools: [...]} structure
#
# Example:
#   tools='[{"name": "kimi_analyze", "description": "..."}]'
#   mcp_send_tools_list "123" "$tools"
mcp_send_tools_list() {
    local id="${1:-}"
    local tools_json="${2:-[]}"
    
    jq -n \
        --arg id "$id" \
        --argjson tools "$tools_json" \
        '{
            jsonrpc: "2.0",
            id: (if $id == "" then null else $id end),
            result: {
                tools: $tools
            }
        }'
}

# mcp_validate_request - Validate that a request is a valid JSON-RPC 2.0 request
#
# Arguments:
#   $1 - The parsed request JSON (output from mcp_parse_request)
#
# Output: "valid" if valid, error message if invalid
#
# Returns: 0 if valid, 1 if invalid
#
# Example:
#   if ! mcp_validate_request "$parsed"; then
#       mcp_error_invalid_request "$id" "Invalid request"
#   fi
mcp_validate_request() {
    local parsed="${1:-}"
    
    # Check if parsed is empty or null
    if [[ -z "$parsed" || "$parsed" == "{}" || "$parsed" == "null" ]]; then
        echo "Invalid JSON or empty request"
        return 1
    fi
    
    # Check for required fields using jq
    local has_jsonrpc
    has_jsonrpc=$(echo "$parsed" | jq -r 'has("jsonrpc")')
    
    # Since mcp_parse_request extracts fields, we check if method exists
    local method
    method=$(echo "$parsed" | jq -r '.method // empty')
    
    if [[ -z "$method" ]]; then
        echo "Missing required field: method"
        return 1
    fi
    
    echo "valid"
    return 0
}

# mcp_log_debug - Log debug message to stderr
#
# Arguments:
#   $1 - Message to log
#
# Output: Message to stderr (never stdout to avoid protocol corruption)
#
# Example:
#   mcp_log_debug "Processing request: $method"
mcp_log_debug() {
    local message="${1:-}"
    echo "[DEBUG] $message" >&2
}

# mcp_log_error - Log error message to stderr
#
# Arguments:
#   $1 - Error message to log
#
# Output: Error message to stderr
#
# Example:
#   mcp_log_error "Failed to parse request: $error"
mcp_log_error() {
    local message="${1:-}"
    echo "[ERROR] $message" >&2
}

# Export all functions for use by other scripts
export -f mcp_parse_request
export -f mcp_send_result
export -f mcp_send_response
export -f mcp_send_initialize_result
export -f mcp_send_tools_list
export -f mcp_validate_request
export -f mcp_log_debug
export -f mcp_log_error

# Export constants
export MCP_PROTOCOL_VERSION
export MCP_SERVER_NAME
export MCP_SERVER_VERSION
