# Phase 8: MCP Bridge - Context

**Gathered:** 2026-02-05
**Status:** Ready for planning

<domain>
## Phase Boundary

Implement an MCP server exposing Kimi K2.5 as callable tools for external AI systems. The server provides 4 tools (analyze, implement, refactor, verify) that external AI systems can invoke via the Model Context Protocol. This phase focuses on local/stdio transport for CLI integrations — HTTP transport and authentication are deferred.

</domain>

<decisions>
## Implementation Decisions

### Tool Interface Design
- **Synchronous only** — Tools return complete results, no streaming
- **Hybrid input structure** — Required `prompt` string + optional structured fields (`files`, `context`, `constraints`)
- **File path references** — Caller provides file paths, MCP server reads file contents
- **Simple text output** — Return Kimi's response as plain string (not structured JSON)

### Transport & Protocol Behavior
- **stdio as primary transport** — Focus on local CLI tools and desktop app integrations
- **No authentication** — Assume local/trusted network only (no API keys or OAuth)
- **Fail fast on errors** — Immediate error response, caller responsible for retry logic
- **Single connection** — Serialize requests, no concurrent connection handling

### Error Handling Strategy
- **Generic MCP error codes** — Use standard MCP error types (InternalError, InvalidRequest, etc.)
- **Context-aware error detection** — Parse Kimi CLI stderr to determine error type (timeout vs invalid input vs system error)
- **Binary success/failure** — No partial successes or truncation handling
- **Include stderr in errors** — Pass through Kimi CLI error output in error messages

### Configuration & Defaults
- **Hybrid configuration** — Global defaults in config file, per-call overrides supported
- **Minimal configurable settings** — Only model selection (K2 vs K2.5) and timeout
- **Config file + environment variables** — JSON config at `~/.config/kimi-mcp/config.json` with `KIMI_MCP_*` env var overrides
- **Balanced defaults** — K2 model (faster/cheaper), 30 second timeout

### OpenCode's Discretion
- Exact MCP server implementation details (library choice, class structure)
- File reading implementation (caching, large file handling)
- Error message formatting and verbosity
- Config file schema and validation
- Tool parameter validation logic

</decisions>

<specifics>
## Specific Ideas

- "I want it simple — stdio for local use, no auth complexity"
- "Fail fast is fine, the caller can retry if needed"
- "Just give me Kimi's output as text, don't over-structure it"
- "K2 by default for speed, K2.5 when I need the extra capability"

</specifics>

<deferred>
## Deferred Ideas

- HTTP/SSE transport with authentication — future enhancement for remote deployments
- Streaming responses — could be added later if needed
- Concurrent request handling — single connection keeps it simple for now
- Partial success handling — binary results are cleaner
- Full parameter control (temperature, max tokens, etc.) — minimal config is sufficient

</deferred>

---

*Phase: 08-mcp-bridge*
*Context gathered: 2026-02-05*
