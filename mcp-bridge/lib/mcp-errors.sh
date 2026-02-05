#!/bin/bash
# mcp-errors.sh - MCP Error Code Definitions and Response Builders
#
# Purpose: Provides standard JSON-RPC 2.0 error codes and functions to build
#          properly formatted MCP error responses using jq for JSON generation.
#
# Error Code Reference Table (per JSON-RPC 2.0 Specification):
# ┌─────────┬─────────────────────┬──────────────────────────────────────────┐
# │  Code   │      Message        │              Meaning                     │
# ├─────────┼─────────────────────┼──────────────────────────────────────────┤
# │ -32700  │ Parse error         │ Invalid JSON was received by the server  │
# │ -32600  │ Invalid Request     │ The JSON sent is not a valid Request obj │
# │ -32601  │ Method not found    │ The method does not exist / is not avail │
# │ -32602  │ Invalid params      │ Invalid method parameter(s)              │
# │ -32603  │ Internal error      │ Internal JSON-RPC error                  │
# │ -32000  │ Server error        │ Implementation-defined server error      │
# └─────────┴─────────────────────┴──────────────────────────────────────────┘
#
# Usage Examples:
#   source mcp-errors.sh
#   mcp_error_parse "123" "Invalid JSON" | jq .
#   mcp_error_method_not_found "456" "tools/unknown" | jq .
#
# Dependencies: jq (1.6+)

# Standard JSON-RPC 2.0 Error Codes
readonly MCP_ERROR_PARSE=-32700
readonly MCP_ERROR_INVALID_REQUEST=-32600
readonly MCP_ERROR_METHOD_NOT_FOUND=-32601
readonly MCP_ERROR_INVALID_PARAMS=-32602
readonly MCP_ERROR_INTERNAL=-32603
readonly MCP_ERROR_SERVER=-32000

# mcp_error_parse - Returns JSON-RPC error response for parse errors
# 
# Arguments:
#   $1 - Request ID (can be empty string for null, or any valid JSON id)
#   $2 - Error message
#   $3 - Optional error data (JSON object/array as string, defaults to null)
#
# Returns: JSON-RPC 2.0 error response to stdout
#
# Example:
#   mcp_error_parse "" "Invalid JSON: unexpected token" '{"line": 5}'
mcp_error_parse() {
    local id="${1:-}"
    local message="${2:-Parse error}"
    local data="${3:-null}"
    
    jq -n \
        --arg id "$id" \
        --argjson code "$MCP_ERROR_PARSE" \
        --arg message "$message" \
        --argjson data "$data" \
        '{
            jsonrpc: "2.0",
            id: (if $id == "" then null else $id end),
            error: {
                code: $code,
                message: $message,
                data: $data
            }
        }'
}

# mcp_error_invalid_request - Returns JSON-RPC error for invalid request
#
# Arguments:
#   $1 - Request ID
#   $2 - Error message
#   $3 - Optional error data (defaults to null)
#
# Returns: JSON-RPC 2.0 error response to stdout
#
# Example:
#   mcp_error_invalid_request "123" "Missing required field: method"
mcp_error_invalid_request() {
    local id="${1:-}"
    local message="${2:-Invalid Request}"
    local data="${3:-null}"
    
    jq -n \
        --arg id "$id" \
        --argjson code "$MCP_ERROR_INVALID_REQUEST" \
        --arg message "$message" \
        --argjson data "$data" \
        '{
            jsonrpc: "2.0",
            id: (if $id == "" then null else $id end),
            error: {
                code: $code,
                message: $message,
                data: $data
            }
        }'
}

# mcp_error_method_not_found - Returns JSON-RPC error for unknown method
#
# Arguments:
#   $1 - Request ID
#   $2 - Method name that was not found
#
# Returns: JSON-RPC 2.0 error response to stdout
#
# Example:
#   mcp_error_method_not_found "456" "tools/unknown"
mcp_error_method_not_found() {
    local id="${1:-}"
    local method="${2:-unknown}"
    
    jq -n \
        --arg id "$id" \
        --argjson code "$MCP_ERROR_METHOD_NOT_FOUND" \
        --arg message "Method not found: $method" \
        '{
            jsonrpc: "2.0",
            id: (if $id == "" then null else $id end),
            error: {
                code: $code,
                message: $message
            }
        }'
}

# mcp_error_invalid_params - Returns JSON-RPC error for invalid parameters
#
# Arguments:
#   $1 - Request ID
#   $2 - Error message describing the parameter issue
#   $3 - Optional error data with parameter details (defaults to null)
#
# Returns: JSON-RPC 2.0 error response to stdout
#
# Example:
#   mcp_error_invalid_params "789" "Missing required parameter: prompt"
mcp_error_invalid_params() {
    local id="${1:-}"
    local message="${2:-Invalid params}"
    local data="${3:-null}"
    
    jq -n \
        --arg id "$id" \
        --argjson code "$MCP_ERROR_INVALID_PARAMS" \
        --arg message "$message" \
        --argjson data "$data" \
        '{
            jsonrpc: "2.0",
            id: (if $id == "" then null else $id end),
            error: {
                code: $code,
                message: $message,
                data: $data
            }
        }'
}

# mcp_error_internal - Returns JSON-RPC error for internal server errors
#
# Arguments:
#   $1 - Request ID
#   $2 - Error message
#   $3 - Optional error data (defaults to null)
#
# Returns: JSON-RPC 2.0 error response to stdout
#
# Example:
#   mcp_error_internal "999" "Failed to invoke Kimi CLI"
mcp_error_internal() {
    local id="${1:-}"
    local message="${2:-Internal error}"
    local data="${3:-null}"
    
    jq -n \
        --arg id "$id" \
        --argjson code "$MCP_ERROR_INTERNAL" \
        --arg message "$message" \
        --argjson data "$data" \
        '{
            jsonrpc: "2.0",
            id: (if $id == "" then null else $id end),
            error: {
                code: $code,
                message: $message,
                data: $data
            }
        }'
}

# mcp_error_server - Returns JSON-RPC error for generic server errors
#
# Arguments:
#   $1 - Request ID
#   $2 - Error message
#   $3 - Optional error data (defaults to null)
#
# Returns: JSON-RPC 2.0 error response to stdout
#
# Example:
#   mcp_error_server "111" "Configuration file not found"
mcp_error_server() {
    local id="${1:-}"
    local message="${2:-Server error}"
    local data="${3:-null}"
    
    jq -n \
        --arg id "$id" \
        --argjson code "$MCP_ERROR_SERVER" \
        --arg message "$message" \
        --argjson data "$data" \
        '{
            jsonrpc: "2.0",
            id: (if $id == "" then null else $id end),
            error: {
                code: $code,
                message: $message,
                data: $data
            }
        }'
}

# Export all error functions for use by other scripts
export -f mcp_error_parse
export -f mcp_error_invalid_request
export -f mcp_error_method_not_found
export -f mcp_error_invalid_params
export -f mcp_error_internal
export -f mcp_error_server

# Export error code constants
export MCP_ERROR_PARSE
export MCP_ERROR_INVALID_REQUEST
export MCP_ERROR_METHOD_NOT_FOUND
export MCP_ERROR_INVALID_PARAMS
export MCP_ERROR_INTERNAL
export MCP_ERROR_SERVER
