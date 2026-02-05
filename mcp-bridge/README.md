# Kimi MCP Bridge

Expose Kimi K2.5 as MCP (Model Context Protocol) tools for external AI systems.

## Installation

The MCP bridge is installed automatically with:
```bash
./install.sh
```

## Quick Start

### Option 1: Use as Standalone MCP Server

Start the MCP server directly:
```bash
kimi-mcp start
```

Or directly:
```bash
./mcp-bridge/bin/kimi-mcp-server
```

Other AI systems (Claude Code, etc.) can connect to this server via stdio.

### Option 2: Use Through Kimi CLI (Recommended)

Kimi CLI has built-in MCP client support. Register our server:

```bash
# Register Kimi MCP Bridge with Kimi CLI
kimi-mcp-setup install

# Verify it's working
kimi-mcp-setup status

# Test the connection
kimi mcp test kimi-bridge
```

Now Kimi CLI can use the bridge tools:
```bash
kimi mcp list
```

### Test the Server

```bash
# Initialize
echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-11-25"}}' | kimi-mcp

# List tools
echo '{"jsonrpc":"2.0","id":2,"method":"tools/list"}' | kimi-mcp

# Call analyze tool
echo '{
  "jsonrpc": "2.0",
  "id": 3,
  "method": "tools/call",
  "params": {
    "name": "kimi_analyze",
    "arguments": {
      "prompt": "Explain this code",
      "files": ["./example.js"]
    }
  }
}' | kimi-mcp
```

## Configuration

### Server Configuration

Edit `~/.config/kimi-mcp/config.json`:

```json
{
  "model": "k2",
  "timeout": 30,
  "max_file_size": 1048576
}
```

Or use environment variables:
- `KIMI_MCP_MODEL` - Default model (k2 or k2.5)
- `KIMI_MCP_TIMEOUT` - Timeout in seconds

### Kimi CLI Integration

The `kimi-mcp-setup` helper manages Kimi CLI's MCP configuration at `~/.kimi/mcp.json`:

```bash
kimi-mcp-setup install   # Add to Kimi CLI
kimi-mcp-setup remove    # Remove from Kimi CLI
kimi-mcp-setup status    # Check configuration
```

## Available Tools

- `kimi_analyze` - Analyze code with specified role
- `kimi_implement` - Implement features/fixes
- `kimi_refactor` - Refactor with safety checks
- `kimi_verify` - Verify against requirements

## Testing

```bash
cd mcp-bridge
./tests/run-tests.sh
```
