# Phase 8: MCP Bridge - Research

**Researched:** 2026-02-05
**Domain:** Model Context Protocol (MCP) Server Implementation
**Confidence:** HIGH

## Summary

This research covers the implementation of an MCP server that exposes Kimi K2.5 as callable tools for external AI systems. The Model Context Protocol (MCP) is an open standard for connecting AI applications to external systems, using JSON-RPC 2.0 over stdio transport.

**Key findings:**
- MCP uses JSON-RPC 2.0 with newline-delimited messages over stdio
- The current protocol version is **2025-11-25**
- Tools are defined with JSON Schema input/output schemas
- Error handling distinguishes between protocol errors (JSON-RPC codes) and tool execution errors (`isError: true`)
- stdio transport requires strict stdout hygiene (only MCP messages allowed)

**Primary recommendation:** Implement a pure Bash MCP server that reads JSON-RPC requests from stdin, validates them using jq, invokes the Kimi CLI with appropriate parameters, and returns properly formatted JSON-RPC responses. Use stderr for logging only.

## Standard Stack

### Core
| Library/Tool | Version | Purpose | Why Standard |
|--------------|---------|---------|--------------|
| jq | 1.6+ | JSON parsing/generation | Required for JSON-RPC message handling in Bash |
| Bash | 4.0+ | Server runtime | Target shell per project requirements |
| Kimi CLI | latest | LLM backend | The tool being exposed via MCP |
| MCP Protocol | 2025-11-25 | Communication standard | Current stable protocol version |

### Supporting
| Tool | Purpose | When to Use |
|------|---------|-------------|
| PowerShell | Windows fallback | When Bash unavailable on Windows |
| mcp CLI inspector | Testing/debugging | Development and verification |

### No External Dependencies Required
Unlike Python/TypeScript implementations that use SDKs, a Bash implementation will implement the protocol directly, which is feasible given:
- JSON-RPC is simple request/response over stdio
- Tool definitions are static JSON schemas
- Message parsing/generation can be done with jq

## Architecture Patterns

### MCP Server Lifecycle (stdio transport)

```
┌─────────────────────────────────────────────────────────────┐
│                     MCP Server Lifecycle                     │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  1. INITIALIZATION                                          │
│     ┌─────────┐                    ┌─────────┐              │
│     │ Client  │ ──initialize─────▶ │ Server  │              │
│     │         │ ◀──InitializeResult│         │              │
│     │         │ ──initialized────▶ │         │              │
│     └─────────┘                    └─────────┘              │
│                                                              │
│  2. OPERATION PHASE                                         │
│     ┌─────────┐                    ┌─────────┐              │
│     │ Client  │ ──tools/list─────▶ │ Server  │              │
│     │         │ ◀──Tool[]─────────│         │              │
│     │         │ ──tools/call─────▶ │         │              │
│     │         │ ◀──ToolResult─────│         │              │
│     └─────────┘                    └─────────┘              │
│                                                              │
│  3. SHUTDOWN                                                │
│     Client closes stdin → Server exits                      │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### Recommended Project Structure

```
08-mcp-bridge/
├── bin/
│   └── kimi-mcp-server          # Main MCP server executable
├── lib/
│   ├── mcp-core.sh              # JSON-RPC protocol handling
│   ├── mcp-tools.sh             # Tool definitions and handlers
│   ├── mcp-errors.sh            # Error handling utilities
│   └── config.sh                # Configuration management
├── config/
│   └── default.json             # Default configuration
└── tests/
    ├── test-mcp-core.bats       # Protocol tests
    └── test-tools.bats          # Tool handler tests
```

### Pattern 1: JSON-RPC Message Loop
**What:** Continuously read lines from stdin, parse as JSON-RPC, route to handlers
**When to use:** All stdio MCP servers
**Example:**
```bash
#!/bin/bash
# Source: MCP Specification 2025-11-25, stdio transport section

# Main message loop
while IFS= read -r line; do
    # Parse JSON-RPC request
    method=$(echo "$line" | jq -r '.method // empty')
    id=$(echo "$line" | jq -r '.id // empty')
    params=$(echo "$line" | jq -r '.params // {}')
    
    case "$method" in
        "initialize")
            handle_initialize "$id" "$params"
            ;;
        "tools/list")
            handle_tools_list "$id"
            ;;
        "tools/call")
            handle_tools_call "$id" "$params"
            ;;
        *)
            send_error "$id" -32601 "Method not found"
            ;;
    esac
done
```

### Pattern 2: Tool Handler Registration
**What:** Map tool names to handler functions with input validation
**When to use:** Processing tools/call requests
**Example:**
```bash
# Tool handler dispatch
declare -A TOOL_HANDLERS=(
    ["kimi_analyze"]="handle_kimi_analyze"
    ["kimi_implement"]="handle_kimi_implement"
    ["kimi_refactor"]="handle_kimi_refactor"
    ["kimi_verify"]="handle_kimi_verify"
)

handle_tools_call() {
    local id="$1"
    local params="$2"
    
    local tool_name=$(echo "$params" | jq -r '.name')
    local arguments=$(echo "$params" | jq -r '.arguments // {}')
    
    local handler="${TOOL_HANDLERS[$tool_name]}"
    if [[ -n "$handler" ]]; then
        "$handler" "$id" "$arguments"
    else
        send_error "$id" -32602 "Unknown tool: $tool_name"
    fi
}
```

### Pattern 3: Configuration Hierarchy
**What:** Load config from file, override with environment variables
**When to use:** Server initialization
**Example:**
```bash
# Config loading with env override
load_config() {
    local config_file="${HOME}/.config/kimi-mcp/config.json"
    
    # Start with defaults
    MODEL="${KIMI_MCP_MODEL:-k2}"
    TIMEOUT="${KIMI_MCP_TIMEOUT:-30}"
    
    # Load from file if exists
    if [[ -f "$config_file" ]]; then
        local file_model=$(jq -r '.model // empty' "$config_file")
        local file_timeout=$(jq -r '.timeout // empty' "$config_file")
        [[ -n "$file_model" ]] && MODEL="$file_model"
        [[ -n "$file_timeout" ]] && TIMEOUT="$file_timeout"
    fi
    
    # Environment variables take precedence
    MODEL="${KIMI_MCP_MODEL:-$MODEL}"
    TIMEOUT="${KIMI_MCP_TIMEOUT:-$TIMEOUT}"
}
```

### Anti-Patterns to Avoid
- **Writing to stdout for logging:** Corrupts JSON-RPC protocol; use stderr only
- **Not validating JSON input:** Can cause jq errors and server crashes
- **Synchronous blocking without timeout:** Can hang indefinitely
- **Not handling signals:** Prevents clean shutdown

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| JSON parsing | Custom regex parsing | jq | jq handles escaping, nesting, Unicode correctly |
| JSON Schema validation | Manual parameter checking | jq + basic validation | Complex nested schemas are error-prone |
| Process timeout | wait with sleep | timeout command | Built-in, handles signals correctly |
| Configuration parsing | Custom config format | JSON + jq | Standard format, easy to edit |
| Logging | echo to stdout | echo to stderr | Protocol compliance |

**Key insight:** While a full SDK (Python/TypeScript) provides more features, for a simple stdio server with 4 tools, direct protocol implementation in Bash is feasible and reduces dependencies. The complexity is in correct JSON-RPC formatting, not business logic.

## Common Pitfalls

### Pitfall 1: stdout Pollution
**What goes wrong:** Debug print statements or command output leaks to stdout, corrupting JSON-RPC messages
**Why it happens:** Bash defaults to stdout; subprocesses may write to stdout
**How to avoid:**
- Always redirect logging to stderr: `echo "debug" >&2`
- Redirect subprocess stdout when not needed: `cmd > /dev/null`
- Use `exec` to ensure file descriptors are clean
**Warning signs:** Client reports "parse error" or "invalid JSON"

### Pitfall 2: JSON Injection
**What goes wrong:** User input containing quotes/newlines breaks JSON generation
**Why it happens:** String interpolation without proper escaping
**How to avoid:**
- Always use jq for JSON construction: `jq -n --arg text "$input" '{text: $text}'`
- Never use shell string interpolation for JSON values
**Warning signs:** Parse errors on specific inputs, tool calls failing with valid arguments

### Pitfall 3: Blocking on Large Files
**What goes wrong:** Reading large files into memory hangs the server
**Why it happens:** No size limits on file reading
**How to avoid:**
- Check file size before reading: `stat -f%z "$file"` (macOS) or `stat -c%s "$file"` (Linux)
- Implement size limits (e.g., 1MB max)
- Stream large files or return error
**Warning signs:** Server becomes unresponsive, timeout errors

### Pitfall 4: Missing Request ID
**What goes wrong:** Responses don't match requests, client hangs
**Why it happens:** Not echoing back the request ID in responses
**How to avoid:**
- Always extract and return the `id` field from requests
- Handle null IDs (notifications) by not sending response
**Warning signs:** Client timeout, "request ID mismatch" errors

### Pitfall 5: Tool Result Format
**What goes wrong:** Tool returns raw string instead of MCP ToolResult format
**Why it happens:** Confusing tool output with JSON-RPC result
**How to avoid:**
- Tool results must be wrapped: `{"content": [{"type": "text", "text": "..."}], "isError": false}`
- Use `isError: true` for tool execution errors (not protocol errors)
**Warning signs:** Client can't display tool results

## Code Examples

### Initialize Request Handler
```bash
# Source: MCP Specification 2025-11-25, Lifecycle section
handle_initialize() {
    local id="$1"
    local params="$2"
    
    # Extract client protocol version
    local client_version=$(echo "$params" | jq -r '.protocolVersion // "2024-11-05"')
    
    # Negotiate version (server supports 2025-11-25)
    local server_version="2025-11-25"
    if [[ "$client_version" != "$server_version" ]]; then
        # Client doesn't support our version, use what they asked for if we can
        # For now, we only support 2025-11-25
        server_version="2025-11-25"
    fi
    
    # Send InitializeResult
    jq -n \
        --arg id "$id" \
        --arg version "$server_version" \
        '{
            jsonrpc: "2.0",
            id: $id,
            result: {
                protocolVersion: $version,
                capabilities: {
                    tools: {
                        listChanged: false
                    }
                },
                serverInfo: {
                    name: "kimi-mcp-server",
                    version: "1.0.0"
                }
            }
        }'
}
```

### Tool Definition Schema
```bash
# Source: MCP Specification 2025-11-25, Tools section
get_tool_definitions() {
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
                        }
                    },
                    required: ["prompt"]
                }
            }
        ]
    }'
}
```

### Tool Call Handler
```bash
handle_kimi_analyze() {
    local id="$1"
    local arguments="$2"
    
    # Extract parameters
    local prompt=$(echo "$arguments" | jq -r '.prompt // empty')
    local files=$(echo "$arguments" | jq -r '.files // empty')
    local context=$(echo "$arguments" | jq -r '.context // empty')
    local role=$(echo "$arguments" | jq -r '.role // "general"')
    
    # Validate required parameter
    if [[ -z "$prompt" ]]; then
        send_tool_error "$id" "Missing required parameter: prompt"
        return
    fi
    
    # Build Kimi CLI arguments
    local kimi_args=()
    
    # Add files if provided
    if [[ -n "$files" && "$files" != "null" ]]; then
        local file_count=$(echo "$files" | jq 'length')
        for ((i=0; i<file_count; i++)); do
            local file_path=$(echo "$files" | jq -r ".[$i]")
            if [[ -f "$file_path" ]]; then
                # Read file content and add to prompt
                local content=$(cat "$file_path" 2>/dev/null)
                prompt="${prompt}

File: $file_path
$content"
            fi
        done
    fi
    
    # Add context if provided
    if [[ -n "$context" && "$context" != "null" ]]; then
        prompt="${prompt}

Context: $context"
    fi
    
    # Call Kimi CLI with timeout
    local result
    if ! result=$(timeout "$TIMEOUT" kimi "$prompt" 2>&1); then
        local exit_code=$?
        if [[ $exit_code -eq 124 ]]; then
            send_tool_error "$id" "Tool execution timed out after ${TIMEOUT}s"
        else
            send_tool_error "$id" "Kimi CLI error: $result"
        fi
        return
    fi
    
    # Return successful result
    send_tool_result "$id" "$result"
}

send_tool_result() {
    local id="$1"
    local text="$2"
    
    jq -n \
        --arg id "$id" \
        --arg text "$text" \
        '{
            jsonrpc: "2.0",
            id: $id,
            result: {
                content: [
                    {
                        type: "text",
                        text: $text
                    }
                ],
                isError: false
            }
        }'
}

send_tool_error() {
    local id="$1"
    local message="$2"
    
    jq -n \
        --arg id "$id" \
        --arg message "$message" \
        '{
            jsonrpc: "2.0",
            id: $id,
            result: {
                content: [
                    {
                        type: "text",
                        text: $message
                    }
                ],
                isError: true
            }
        }'
}
```

### Error Response Handler
```bash
# Source: JSON-RPC 2.0 Specification, Error Object section
send_error() {
    local id="${1:-null}"
    local code="$2"
    local message="$3"
    local data="${4:-null}"
    
    jq -n \
        --arg id "$id" \
        --argjson code "$code" \
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

# Standard JSON-RPC error codes
declare -A ERROR_CODES=(
    [-32700]="Parse error"
    [-32600]="Invalid Request"
    [-32601]="Method not found"
    [-32602]="Invalid params"
    [-32603]="Internal error"
    [-32000]="Server error"
)
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| HTTP+SSE transport | Streamable HTTP | 2025-11-25 | Simpler HTTP implementation, but stdio remains preferred for local tools |
| 2024-11-05 protocol | 2025-11-25 protocol | Nov 2025 | New features, but stdio transport unchanged |
| Python SDK v1 | Python SDK v2 (pre-alpha) | 2026 Q1 | v1 still recommended for production |
| TypeScript SDK v1 | TypeScript SDK v2 (pre-alpha) | 2026 Q1 | v1 still recommended for production |

**Deprecated/outdated:**
- HTTP+SSE transport from 2024-11-05: Replaced by Streamable HTTP in 2025-11-25
- Protocol version 2024-11-05: Still supported but legacy

## Open Questions

1. **Kimi CLI Exit Code Handling**
   - What we know: Kimi CLI returns exit codes 1-9 for CLI errors, 10-13 for wrapper errors
   - What's unclear: Exact mapping of exit codes to error conditions
   - Recommendation: Treat non-zero exit codes as tool execution errors, include stderr in error message

2. **File Size Limits**
   - What we know: Should implement limits to prevent memory issues
   - What's unclear: Appropriate limit for Kimi context window
   - Recommendation: Start with 1MB per file, make configurable

3. **Concurrent Request Handling**
   - What we know: Context specifies single connection, serialize requests
   - What's unclear: Whether to implement request queue or simple sequential processing
   - Recommendation: Simple sequential processing - process one request at a time

4. **Progress Reporting**
   - What we know: MCP supports progress notifications for long-running operations
   - What's unclear: Whether Kimi CLI provides progress information
   - Recommendation: Skip progress reporting for v1 (synchronous only per context)

## Sources

### Primary (HIGH confidence)
- MCP Specification 2025-11-25: https://modelcontextprotocol.io/specification/2025-11-25/
  - Transports section: stdio protocol details
  - Lifecycle section: Initialization sequence
  - Tools section: Tool definition and calling
  - Cancellation section: Request cancellation
- JSON-RPC 2.0 Specification: https://www.jsonrpc.org/specification
  - Error codes and message format
- MCP Python SDK: https://github.com/modelcontextprotocol/python-sdk
  - Implementation patterns and examples

### Secondary (MEDIUM confidence)
- MCP TypeScript SDK: https://github.com/modelcontextprotocol/typescript-sdk
  - Server implementation patterns
- MCP Documentation: https://modelcontextprotocol.io/docs/develop/build-server
  - Tutorial and best practices

### Tertiary (LOW confidence)
- Community examples and blog posts (not directly referenced but inform patterns)

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - Direct from MCP specification
- Architecture: HIGH - Protocol specification is clear
- Pitfalls: MEDIUM - Based on specification warnings and common JSON-RPC issues
- Code examples: HIGH - Derived directly from specification

**Research date:** 2026-02-05
**Valid until:** 2026-03-05 (30 days for stable protocol)

**Protocol version researched:** 2025-11-25 (current)
**Key constraint:** stdio transport only, no HTTP/SSE
