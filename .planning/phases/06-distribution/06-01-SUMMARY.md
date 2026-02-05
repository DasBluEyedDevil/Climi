---
phase: 06-distribution
plan: 01
subsystem: distribution
tags: [installer, uninstaller, bash, multi-platform, backup]
dependencies:
  requires: [05-01, 05-02]  # Slash commands and SKILL.md to install
  provides: [install.sh, uninstall.sh]
  affects: [06-02]  # PowerShell shim needs similar patterns
tech-stack:
  added: []
  patterns: [cli-argument-parsing, version-checking, backup-restore, dry-run-preview]
key-files:
  created: []
  modified: [install.sh, uninstall.sh]
decisions: [extended-existing-scripts, both-gemini-and-kimi-support]
metrics:
  duration: 4m27s
  completed: 2026-02-05
---

# Phase 6 Plan 01: Install/Uninstall Scripts Summary

**One-liner:** Extended install.sh/uninstall.sh with Kimi integration support including CLI args, kimi detection, backup, and dry-run preview.

## What Was Done

### Task 1: Extended install.sh with Kimi support
Extended the existing Gemini-focused install.sh to support Kimi integration:

- **CLI argument parsing**: Added `--global`, `--local`, `--target PATH`, `--force`, `--help` flags
- **Kimi CLI detection**: `find_kimi()` checks KIMI_PATH env var first, then PATH lookup
- **Version checking**: `check_kimi_version()` warns if below MIN_KIMI_VERSION (1.7.0)
- **Platform-specific install instructions**: macOS (brew), Linux/Windows (uv tool install)
- **Kimi component installation**: wrapper, templates, skill definition, slash commands
- **Backup support**: Detects existing installations and offers timestamped backup
- **Creates .kimi-version file** for version tracking

### Task 2: Extended uninstall.sh with dry-run support
Extended the existing uninstall.sh to support Kimi removal and preview:

- **CLI argument parsing**: Added `--target PATH`, `--dry-run`, `--help` flags
- **Detection**: Checks for both Kimi and Gemini installations at target
- **Selective removal**: Options for "everything", "Kimi only", "Gemini only"
- **Dry-run mode**: Shows what would be removed without actually deleting
- **Clean removal**: Removes all Kimi components, cleans empty directories
- **Preserves other plugins**: Does not remove parent directories or unrelated files

## Commits

| Commit | Type | Description |
|--------|------|-------------|
| 2d4e2be | feat | extend install.sh with Kimi integration support |
| 97df6c9 | feat | extend uninstall.sh with Kimi removal and dry-run support |

## Key Files Modified

- `install.sh` - 566 lines, supports both Gemini and Kimi installation
- `uninstall.sh` - 316 lines, supports selective removal with dry-run

## Decisions Made

| Decision | Rationale |
|----------|-----------|
| Extended existing scripts vs. separate scripts | Project is "Multi-Agent-Workflow" supporting both Gemini and Kimi; unified scripts are cleaner |
| Both interactive and CLI modes | Interactive for manual use, CLI args for scripted/automated installs |
| KIMI_PATH env var check first | Addresses Windows PATH loss issue documented in project constraints |
| Dry-run as preview mode | Safer for users to verify what will be removed before committing |

## Deviations from Plan

None - plan executed exactly as written. The plan expected install.sh creation but the project already had one for Gemini; extending it was the right approach to maintain the multi-agent nature of the project.

## Requirements Satisfied

- **DIST-01**: install.sh with multi-target support (--global, --local, --target)
- **DIST-02**: Kimi CLI detection with install instructions
- **DIST-03**: Backup support for existing installations
- **DIST-04**: uninstall.sh with clean removal and dry-run

## Next Phase Readiness

**Phase 6 Plan 02** (PowerShell shim) can proceed:
- install.sh now copies Kimi components correctly
- uninstall.sh handles Kimi component removal
- Both scripts serve as reference for PowerShell equivalents

## Testing Notes

```bash
# Verify install.sh help
./install.sh --help

# Verify uninstall.sh dry-run
./uninstall.sh --dry-run

# Test non-interactive global install
./install.sh --global --force
```
