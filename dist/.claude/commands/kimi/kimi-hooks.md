---
description: Install and manage git hooks for auto-delegation to Kimi
---

# Kimi Hooks

Manage git hooks for automatic Kimi delegation.

## Usage

```
/kimi-hooks [action] [options]
```

## Actions

### install
Install git hooks to enable auto-delegation.

```
/kimi-hooks install [--global] [--local]
```

**Options:**
- `--global` - Install to `~/.config/git/hooks/` (affects all repos)
- `--local` - Install to current repo's `.git/hooks/` (default)

**What it does:**
1. Creates hook scripts in the target directory
2. Sets up `.kimi/hooks.json` configuration
3. Backs up existing hooks
4. Makes hooks executable

**Installed hooks:**
- `pre-commit` - Auto-format and lint fixes before commit
- `post-checkout` - Analyze changed files after branch checkout
- `pre-push` - Run tests and fix failures before push

**Use when:**
- Setting up a new project with auto-delegation
- Want automatic code fixes on commit
- Need pre-push validation

### uninstall
Remove Kimi hooks.

```
/kimi-hooks uninstall [--global] [--local]
```

**Restores:** Original hooks from backup if available.

### status
Check hook installation status.

```
/kimi-hooks status
```

**Shows:**
- Which hooks are installed (global vs local)
- Hook configuration file location
- Enablement status for each hook
- Last run information

## Hook Behavior

### Pre-commit
Runs before each commit.

**Actions:**
1. Stashes unstaged changes
2. Runs auto-formatting on staged files
3. Runs linting and auto-fixes
4. Restores stashed changes

**Configuration:**
```json
{
  "pre_commit": {
    "enabled": true,
    "auto_fix": true,
    "max_file_size_kb": 100
  }
}
```

### Post-checkout
Runs after `git checkout` or `git switch`.

**Actions:**
1. Detects files changed in checkout
2. Analyzes for potential issues
3. Reports findings

**Configuration:**
```json
{
  "post_checkout": {
    "enabled": true,
    "max_files": 10,
    "analyze_patterns": ["*.js", "*.ts", "*.py"]
  }
}
```

### Pre-push
Runs before `git push`.

**Actions:**
1. Runs test suite
2. Attempts to fix failures
3. Blocks push if fixes fail

**Configuration:**
```json
{
  "pre_push": {
    "enabled": true,
    "run_tests": true,
    "auto_fix": true
  }
}
```

## Configuration

**Project config:** `.kimi/hooks.json`

```json
{
  "version": "1.0.0",
  "pre_commit": {
    "enabled": true,
    "auto_fix": true,
    "timeout": 120
  },
  "post_checkout": {
    "enabled": true,
    "max_files": 10
  },
  "pre_push": {
    "enabled": true,
    "run_tests": true
  },
  "global": {
    "model": "k2",
    "timeout": 300,
    "dry_run": false
  }
}
```

**Global config:** `~/.config/kimi/hooks.json`

Project config overrides global config.

## Bypassing Hooks

Emergency bypass (don't block on hook failures):

```bash
# Skip all hooks
KIMI_HOOKS_SKIP=true git commit -m "urgent fix"

# Or configure bypass env var
export KIMI_HOOKS_BYPASS_VAR="KIMI_HOOKS_SKIP"
```

## Examples

### Install hooks locally

```
/kimi-hooks install
```

### Install hooks globally

```
/kimi-hooks install --global
```

### Check status

```
/kimi-hooks status
```

### Uninstall local hooks

```
/kimi-hooks uninstall
```

## Troubleshooting

**"Not a git repository"**
- Run from within a git repository
- Or use `--global` for global installation

**Hooks not running**
- Check: `git config core.hooksPath`
- Verify hooks are executable: `ls -la .git/hooks/`
- Check `.kimi/hooks.json` has `"enabled": true`

**Pre-commit too slow**
- Reduce `max_file_size_kb` in config
- Disable for specific files in `.kimi/hooks.json`
- Use `KIMI_HOOKS_SKIP=true` for quick commits

**Hook failures blocking git**
- Hooks return 0 on skip (don't block)
- Pre-push still fails after auto-fix (by design)
- Check logs in `.kimi/hooks.log`

## Dry Run Mode

Test hooks without making changes:

```json
{
  "global": {
    "dry_run": true
  }
}
```

Shows what Kimi would do without executing.

## See Also

- @.claude/CLAUDE.md — Complete command reference
- @.claude/skills/kimi-delegation/SKILL.md — Delegation patterns
- `cat hooks/README.md` — Detailed hook documentation
