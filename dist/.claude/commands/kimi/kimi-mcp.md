---
description: Start and configure Kimi MCP server for external tool integration
---

# Kimi MCP

Manage the Kimi MCP server for external tool integration.

## Usage

```
/kimi-mcp [action] [options]
```

## Actions

### start
Start the MCP server (reads JSON-RPC from stdin).

```
/kimi-mcp start
```

**What it does:**
1. Starts the MCP server process
2. Listens for JSON-RPC messages on stdin
3. Exposes Kimi as callable tools for external systems
4. Responds with JSON-RPC on stdout

**Use when:**
- External AI systems need to invoke Kimi
- Building MCP client integrations
- Testing MCP tool calls

**Example workflow:**
```bash
# Terminal 1: Start server
echo '{"jsonrpc":"2.0","id":1,"method":"tools/list"}' | kimi-mcp start

# Or interactively
kimi-mcp start
# Then type JSON-RPC requests
```

### setup
Configure MCP for Claude Code or other clients.

```
/kimi-mcp setup [--claude]
```

**Options:**
- `--claude` - Configure specifically for Claude Code integration

**What it does:**
1. Creates MCP configuration file
2. Registers Kimi tools with the client
3. Sets up default roles and timeouts

### status
Check MCP server and configuration status.

```
/kimi-mcp status
```

**Shows:**
- Server binary location
- Configuration file status
- Available tools
- Default settings

## MCP Tools

When running, the server exposes these tools:

| Tool | Purpose | Input |
|------|---------|-------|
| `kimi_analyze` | Analyze code/files | `{ "prompt": "...", "files": [...] }` |
| `kimi_implement` | Implement features | `{ "prompt": "...", "files": [...] }` |
| `kimi_refactor` | Refactor code | `{ "prompt": "...", "files": [...] }` |
| `kimi_verify` | Verify changes | `{ "prompt": "...", "files": [...] }` |

## Configuration

**Config file:** `~/.config/kimi-mcp/config.json`

```json
{
  "model": "k2",
  "timeout": 300,
  "roles": {
    "analyze": "reviewer",
    "implement": "implementer",
    "refactor": "refactorer",
    "verify": "reviewer"
  }
}
```

**Environment variables:**
- `KIMI_MCP_MODEL` - Default model (k2 or k2.5)
- `KIMI_MCP_TIMEOUT` - Timeout in seconds

## Examples

### Test MCP server

```
/kimi-mcp start
```

Then paste:
```json
{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-11-25","capabilities":{},"clientInfo":{"name":"test","version":"1.0.0"}}}
```

### Setup for Claude Code

```
/kimi-mcp setup --claude
```

### Check status

```
/kimi-mcp status
```

## Troubleshooting

**"kimi-mcp: command not found"**
- Ensure `~/.local/bin` is in PATH
- Run: `export PATH="$HOME/.local/bin:$PATH"`

**"jq: command not found"**
- MCP server requires jq for JSON processing
- Install: `brew install jq` (macOS) or `apt-get install jq` (Linux)

**Server not responding**
- Check that input is valid JSON-RPC
- Ensure proper newline termination
- Verify protocol version matches

## Protocol

Implements MCP (Model Context Protocol) version 2025-11-25.

**Transport:** stdio (JSON-RPC 2.0)

**Methods:**
- `initialize` - Client/server handshake
- `tools/list` - List available tools
- `tools/call` - Invoke a tool

## See Also

- @.claude/CLAUDE.md — Complete command reference
- @.claude/skills/kimi-delegation/SKILL.md — Delegation patterns
