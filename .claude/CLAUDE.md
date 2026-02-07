# Claude Code Integration Guide

Multi-Agent Workflow v2.0 — Claude architects, Kimi implements.

---

## Quick Reference

| Command | Purpose | When to Use |
|---------|---------|-------------|
| `/kimi-analyze` | Deep codebase analysis | Understanding unfamiliar code |
| `/kimi-trace` | Trace logic across files | Finding where functionality lives |
| `/kimi-verify` | Verify implementation | Checking changes meet requirements |
| `/kimi-audit` | Security/quality audit | Reviewing for issues |
| `/kimi-mcp` | MCP server operations | Starting/configuring MCP |
| `/kimi-hooks` | Git hooks management | Installing/managing hooks |

---

## Kimi R&D Subagent

**Division of labor:**
- **Claude (Architect):** Design, plan, review, coordinate, decide
- **Kimi (Developer):** Implement, debug, refactor, test, execute

### Model Selection (v2.0)

The system intelligently selects between K2 and K2.5:

| Task Type | Model | Examples |
|-----------|-------|----------|
| Routine | K2 | Refactoring, tests, debugging, APIs |
| Creative/UI | K2.5 | Components, styling, UX, animations |

**Override:** Set `KIMI_FORCE_MODEL=k2.5` to force specific model.

### Delegation Patterns

**Always delegate:**
- Feature implementation from your specs
- Bug fixes and debugging
- Code refactoring
- Test writing
- Multi-file changes you've designed

**Always keep:**
- Architecture decisions
- Design reviews and approvals
- User communication
- Strategic planning

---

## Slash Commands

### Analysis Commands

#### `/kimi-analyze [directory] [question]`
Deep codebase analysis using Kimi's large context window.

**Example:**
```
/kimi-analyze src/auth "How is JWT authentication implemented?"
```

**What it does:**
1. Kimi analyzes the specified directory
2. Returns structured findings with file:line references
3. Claude uses findings to guide implementation

---

#### `/kimi-trace [pattern]`
Trace code patterns across the codebase.

**Example:**
```
/kimi-trace "function.*handleAuth"
```

---

#### `/kimi-verify [requirements]`
Verify implementation against requirements.

**Example:**
```
/kimi-verify "All API endpoints require authentication"
```

---

#### `/kimi-audit [scope]`
Security and quality audit.

**Example:**
```
/kimi-audit src/auth
```

---

### MCP Commands (v2.0)

#### `/kimi-mcp [action]`
Manage MCP server for external tool integration.

**Actions:**
- `start` - Start MCP server (reads JSON-RPC from stdin)
- `setup` - Configure MCP for Claude Code
- `status` - Check MCP server status

**Example:**
```
/kimi-mcp start
```

**Use when:**
- External tools need to invoke Kimi
- Building integrations with other AI systems
- Using Kimi via MCP protocol

See: @.claude/commands/kimi/kimi-mcp.md

---

### Hooks Commands (v2.0)

#### `/kimi-hooks [action]`
Manage git hooks for auto-delegation.

**Actions:**
- `install` - Install hooks to current repo
- `install --global` - Install hooks globally
- `uninstall` - Remove hooks
- `status` - Check hook status

**Example:**
```
/kimi-hooks install
```

**Use when:**
- Setting up auto-delegation on git operations
- Configuring pre-commit auto-fixes
- Managing hook configuration

See: @.claude/commands/kimi/kimi-hooks.md

---

## Roles Reference

| Role | Type | Best For |
|------|------|----------|
| `implementer` | Action | Feature implementation |
| `debugger` | Action | Bug investigation |
| `refactorer` | Action | Code restructuring |
| `simplifier` | Action | Complexity reduction |
| `reviewer` | Analysis | Code review |
| `auditor` | Analysis | Quality audit |
| `security` | Analysis | Security review |

---

## Environment Variables

| Variable | Purpose | Default |
|----------|---------|---------|
| `KIMI_FORCE_MODEL` | Override auto-selection | (none) |
| `KIMI_HOOKS_SKIP` | Bypass hooks | `false` |
| `KIMI_MCP_MODEL` | MCP default model | `k2` |
| `KIMI_MCP_TIMEOUT` | MCP timeout | `300` |

---

## Workflow Examples

### Implementing a Feature

1. **Research:** `/kimi-analyze src "How are features structured?"`
2. **Design:** (Claude) Plan implementation approach
3. **Implement:** Delegate to Kimi with implementer role
4. **Verify:** `/kimi-verify "Feature works as specified"`

### Debugging an Issue

1. **Trace:** `/kimi-trace "error pattern"`
2. **Analyze:** `/kimi-analyze src "What causes this error?"`
3. **Fix:** Delegate to Kimi with debugger role
4. **Verify:** `/kimi-verify "Issue is resolved"`

---

## Configuration

### Project-level
- `.kimi/config` - Project configuration
- `.kimi/hooks.json` - Hook settings

### Global
- `~/.config/kimi-workflow/config.yaml` - Global settings
- `~/.config/kimi-mcp/config.json` - MCP configuration

---

## Troubleshooting

**Kimi command not found:**
- Ensure `~/.local/bin` is in PATH
- Run `export PATH="$HOME/.local/bin:$PATH"`

**Hooks not running:**
- Check `git config core.hooksPath`
- Verify hooks are executable
- Check `.kimi/hooks.json` enablement

**MCP server errors:**
- Verify jq is installed: `jq --version`
- Check config syntax: `cat ~/.config/kimi-mcp/config.json | jq .`

---

*Multi-Agent Workflow v2.0*
