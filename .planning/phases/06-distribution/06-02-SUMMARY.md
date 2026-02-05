---
phase: 06-distribution
plan: 02
subsystem: distribution
tags: [powershell, windows, shim, cross-platform]

dependency-graph:
  requires:
    - 01-01 # Core wrapper (kimi.agent.wrapper.sh)
  provides:
    - Windows PowerShell entry point
    - Cross-platform bash resolution
  affects:
    - Windows user onboarding
    - Distribution packaging

tech-stack:
  added:
    - PowerShell scripting
  patterns:
    - Multi-source bash resolution
    - Path conversion (Windows to Unix)
    - Exit code propagation

files:
  created:
    - kimi.ps1

decisions:
  - id: bash-resolution-order
    choice: "Git Bash > WSL > MSYS2 > Cygwin > PATH"
    reason: "Git Bash is most common; WSL is modern alternative; MSYS2/Cygwin for legacy"
  - id: wsl-path-conversion
    choice: "Convert C:\\path to /mnt/c/path for WSL"
    reason: "WSL requires Unix-style mount paths"
  - id: script-location
    choice: "kimi.ps1 in project root"
    reason: "Parallel to skills/ directory, easy to find"

metrics:
  duration: 45s
  completed: 2026-02-05
  tasks: 1/1
---

# Phase 06 Plan 02: PowerShell Shim Summary

**One-liner:** PowerShell wrapper that resolves bash from Git Bash/WSL/MSYS2/Cygwin/PATH and delegates to kimi.agent.wrapper.sh

## What Was Built

### kimi.ps1 - PowerShell Shim (183 lines)

A PowerShell entry point for Windows users that:

1. **Bash Resolution** - Finds bash in priority order:
   - Git Bash (`$env:ProgramFiles\Git\bin\bash.exe`)
   - WSL (`wsl.exe bash` after verifying `wsl --status`)
   - MSYS2 (`$env:MSYS2_ROOT\usr\bin\bash.exe`)
   - Cygwin (`$env:CYGWIN_ROOT\bin\bash.exe`)
   - PATH lookup (`bash.exe`)

2. **Path Conversion** - Handles platform differences:
   - Git Bash: `C:\path` → `/c/path`
   - WSL: `C:\path` → `/mnt/c/path`
   - Proper escaping for arguments with spaces/quotes

3. **Argument Handling** - Full pass-through:
   - Captures all arguments via `[Parameter(ValueFromRemainingArguments)]`
   - Escapes single quotes properly for bash
   - Wraps arguments in single quotes for safety

4. **Exit Code Propagation** - `exit $LASTEXITCODE`

5. **Helpful Errors** - Shows install URLs for each option if bash not found

## Key Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Bash priority | Git Bash first | Most common Windows development setup |
| WSL detection | Check `wsl --status` | Avoids slow fallback attempts |
| Path conversion | Platform-specific | Git Bash and WSL use different mount styles |
| Script location | Project root | Easy to discover, parallel to wrapper |

## Files Created

| File | Lines | Purpose |
|------|-------|---------|
| kimi.ps1 | 183 | PowerShell entry point for Windows |

## Commits

| Hash | Type | Description |
|------|------|-------------|
| de13f46 | feat | Add PowerShell shim for Windows users |

## Verification Results

```
kimi.ps1 exists
183 kimi.ps1
```

Bash resolution patterns confirmed:
- Git Bash: ✅
- WSL: ✅
- MSYS2: ✅
- Cygwin: ✅
- PATH: ✅

Argument forwarding: ✅
Exit code propagation: ✅

## Deviations from Plan

None - plan executed exactly as written.

## Requirements Satisfied

| Requirement | Description | Status |
|-------------|-------------|--------|
| DIST-05 | Windows PowerShell shim | ✅ Complete |

## Next Phase Readiness

**Ready for:** 06-03 (README and documentation)

**No blockers.** The PowerShell shim is complete and provides Windows users a native entry point to the bash wrapper.
