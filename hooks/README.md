# Kimi Git Hooks

Auto-delegate coding tasks to Kimi via git hooks.

## Overview

Kimi Git Hooks automatically invoke Kimi analysis at key points in your git workflow:

- **pre-commit**: Analyze staged files and suggest fixes before committing
- **post-checkout**: Summarize changes when switching branches
- **pre-push**: Run tests and analyze failures before pushing

## Quick Start

```bash
# Install hooks in current repository
kimi-hooks install --local

# Or install globally (all repositories)
kimi-hooks install --global

# Check status
kimi-hooks status
```

## Installation

### Local (Per-Project)

Installs hooks in the current repository only:

```bash
kimi-hooks install --local
```

This creates symlinks in `.git/hooks/` pointing to the Kimi hook scripts.

### Global (All Repositories)

Installs hooks for all repositories (requires Git 2.9+):

```bash
kimi-hooks install --global
# Then enable global hooks:
git config --global core.hooksPath '~/.config/git/hooks'
```

### Via install.sh

Hooks are automatically installed when you run the main installer:

```bash
./install.sh
```

## Configuration

Configuration uses JSON files with the following precedence:

1. Environment variables (highest)
2. Project config (`.kimi/hooks.json`)
3. User config (`~/.config/kimi/hooks.json`)
4. Default config (lowest)

### Default Configuration

```json
{
  "version": "1.0",
  "enabled_hooks": ["pre-commit", "post-checkout", "pre-push"],
  "timeout_seconds": 60,
  "auto_fix": false,
  "dry_run": false,
  "file_patterns": ["*.py", "*.js", "*.ts", "*.sh"],
  "hooks": {
    "pre-commit": {
      "enabled": true,
      "auto_fix": false,
      "max_files": 50
    },
    "post-checkout": {
      "enabled": true,
      "max_files": 20
    },
    "pre-push": {
      "enabled": true,
      "run_tests": false,
      "test_command": ""
    }
  }
}
```

### Configuration Options

| Option | Description | Default |
|--------|-------------|---------|
| `enabled_hooks` | List of hook types to enable | `["pre-commit", "post-checkout", "pre-push"]` |
| `timeout_seconds` | Timeout for Kimi analysis | 60 |
| `auto_fix` | Automatically apply fixes | false |
| `dry_run` | Preview without making changes | false |
| `file_patterns` | File patterns to analyze | Language-specific |

### Hook-Specific Settings

Each hook type has its own configuration section:

- **pre-commit**: `auto_fix`, `max_files`, `check_types`
- **post-checkout**: `max_files`, `show_summary`
- **pre-push**: `run_tests`, `test_command`, `auto_fix_failures`

### Enable/Disable Hooks

```bash
# Enable a hook
kimi-hooks enable pre-commit

# Disable a hook
kimi-hooks disable pre-push

# Edit configuration directly
kimi-hooks config
```

## Hook Types

### pre-commit

Runs before each commit. Analyzes staged files for issues.

**Behavior:**
1. Gets list of staged files
2. Filters by file patterns
3. Runs Kimi analysis
4. Shows findings to user
5. If auto_fix enabled: applies fixes and re-stages

**Bypass:**
```bash
git commit --no-verify  # Skip pre-commit hook
# or
KIMI_HOOKS_SKIP=1 git commit
```

### post-checkout

Runs after branch checkout. Summarizes changes between branches.

**Behavior:**
1. Gets files changed between old and new branch
2. Filters by file patterns
3. Runs Kimi analysis for context
4. Shows summary to user

**Note:** Only runs on branch switches, not file checkouts.

### pre-push

Runs before each push. Can run tests and analyze failures.

**Behavior:**
1. Checks if test running is enabled
2. Runs configured test command
3. If tests fail and auto_fix enabled: analyzes and suggests fixes
4. Shows analysis to user

**Configuration:**
```json
{
  "hooks": {
    "pre-push": {
      "run_tests": true,
      "test_command": "npm test",
      "auto_fix_failures": false
    }
  }
}
```

## Bypassing Hooks

### Temporary Bypass

```bash
# Skip all hooks for this command
KIMI_HOOKS_SKIP=1 git commit -m "message"

# Skip pre-commit only
git commit --no-verify

# Skip pre-push only
git push --no-verify
```

### Permanent Disable

```bash
# Disable a specific hook
kimi-hooks disable pre-commit

# Or edit config
kimi-hooks config
```

## Dry Run Mode

Preview what Kimi would do without making changes:

```bash
# Enable dry-run in config
kimi-hooks config
# Set "dry_run": true

# Or via environment
KIMI_HOOKS_DRY_RUN=1 git commit
```

## Environment Variables

| Variable | Description |
|----------|-------------|
| `KIMI_HOOKS_SKIP` | Set to `1` to skip all hooks |
| `KIMI_HOOKS_DRY_RUN` | Set to `1` for dry-run mode |
| `KIMI_HOOKS_DEBUG` | Set to `1` for debug output |
| `KIMI_HOOKS_TIMEOUT` | Override timeout (seconds) |

## Troubleshooting

### Hooks not running

1. Check installation: `kimi-hooks status`
2. Verify hooks are enabled in config
3. Check that files match file_patterns
4. Try with debug: `KIMI_HOOKS_DEBUG=1 git commit`

### "command not found: kimi-hooks"

Ensure the bin directory is in your PATH:
```bash
export PATH="$HOME/.local/bin:$PATH"
```

### Global hooks not working

Verify Git version and core.hooksPath:
```bash
git --version  # Need 2.9+
git config --global core.hooksPath
```

### Slow hooks

- Reduce `timeout_seconds` in config
- Reduce `max_files` for specific hooks
- Disable hooks you don't need

### Conflicts with existing hooks

Local installation backs up existing hooks:
```bash
.git/hooks/pre-commit.backup.20240205120000
```

Restore if needed:
```bash
mv .git/hooks/pre-commit.backup.* .git/hooks/pre-commit
```

## Uninstallation

```bash
# Remove local hooks
kimi-hooks uninstall --local

# Remove global hooks
kimi-hooks uninstall --global

# Remove all hooks
kimi-hooks uninstall
```

## Requirements

- Git 2.9+ (for global hooks)
- Bash 4.0+
- jq 1.6+ (JSON parsing)
- Kimi CLI (for MCP tool invocation)

## See Also

- [MCP Bridge](../mcp-bridge/README.md) - Underlying MCP server
- [Main README](../README.md) - Project overview
