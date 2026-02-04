# Phase 1: Core Wrapper - Context

**Gathered:** 2026-02-04
**Status:** Ready for planning

<domain>
## Phase Boundary

A bash wrapper script that invokes Kimi CLI with a selected agent role, resolves agent files from project-local then global locations, and validates the CLI environment (presence and version). Supports `-r` (role), `-m` (model), and `-w` (working directory) flags passed through to Kimi CLI. Prompt assembly, templates, and developer experience features belong to later phases.

</domain>

<decisions>
## Implementation Decisions

### Output behavior
- Minimal header before Kimi's output — one line with role, model, and other invocation metadata
- Header uses a machine-parseable format (e.g., `[kimi:reviewer:model]`) so Claude Code can parse it in Phase 5
- Silent by default about which agent file was resolved (verbose mode in Phase 4 will expose this)

### Claude's Discretion: Output streams & exit codes
- How to handle stdout vs stderr separation (keep streams clean for piping)
- Exit code scheme — propagate Kimi's exit code for actual runs, use distinct codes for wrapper-specific errors (missing CLI, bad args, version mismatch)

### Error & validation UX
- Platform-specific install instructions when Kimi CLI is not found — detect OS and show the right install command (brew, npm, etc.)
- Plain text errors — no ANSI colors, maximum compatibility with pipes, CI, and log capture
- Version mismatch is a warning, not a hard block — print warning about outdated version but run anyway
- Support `KIMI_PATH` env var override for Kimi binary resolution — checks `KIMI_PATH` first, falls back to PATH lookup (addresses Windows PATH loss after updates)

### Agent file resolution
- Resolution order: project `.kimi/agents/` first, then global install location
- If no `-r` role flag given: invoke Kimi without any agent file (raw/vanilla Kimi CLI)

### Claude's Discretion: Resolution UX
- What to show when a role isn't found (error with available list, fuzzy suggest, or both)
- Whether project-local overriding global should be silent or warned about

### Invocation defaults
- Default model baked into the wrapper (e.g., kimi-k2.5) — user can override with `-m`
- Use the full 300-line budget — build Phase 1 features thoroughly, not a minimal skeleton

### Claude's Discretion: Flag handling & prompt input
- Whether unknown flags pass through to Kimi CLI or get rejected
- Whether prompt can come from stdin (piped input) in addition to positional argument

</decisions>

<specifics>
## Specific Ideas

- Machine-parseable header format matters for Phase 5 Claude Code integration — pick a format that's easy to regex
- The `KIMI_PATH` env var is specifically motivated by Windows PATH instability after system updates
- Research flagged pinning to Kimi CLI v1.7.0 — the version check should reference a pinned minimum version

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 01-core-wrapper*
*Context gathered: 2026-02-04*
