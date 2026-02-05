---
phase: 11-integration-distribution
plan: 01
subsystem: installer
tags: [bash, installer, v2.0, mcp, hooks, model-selection, jq]

# Dependency graph
requires:
  - phase: 08-mcp-bridge
    provides: MCP server binary and CLI wrappers
  - phase: 09-hooks-system
    provides: Hooks scripts and installation library
  - phase: 10-enhanced-skill
    provides: Model selection and cost estimation tools
provides:
  - Enhanced install.sh with v2.0 component installation
  - jq dependency checking with OS-specific guidance
  - MCP server installation and configuration
  - Git hooks interactive installation
  - Model selection tools installation
  - Dry-run mode for testing installations
  - Post-installation summary with next steps
affects:
  - User installation experience
  - v2.0 adoption and upgrade path
  - Phase 11 remaining plans (CLAUDE.md updates, slash commands)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Component-specific install functions following MCP bridge pattern"
    - "Interactive prompts with --flag alternatives for automation"
    - "Dry-run mode for safe installation testing"
    - "Backup preservation for existing user configurations"
    - "PATH verification with helpful guidance"

key-files:
  created: []
  modified:
    - install.sh - Enhanced with v2.0 components (1176 lines)

key-decisions:
  - "Maintain backward compatibility: v1.0 behavior preserved as default"
  - "v2.0 features are additive: installed alongside v1.0 components"
  - "jq is required for MCP: clear error message with install instructions"
  - "Interactive hooks installation: user can opt-in during install"
  - "--with-hooks flag: enables CI/automated installation scenarios"
  - "Dry-run mode: allows testing without making changes"

patterns-established:
  - "Version bump on major feature releases: 1.0.0 → 2.0.0"
  - "Prerequisite validation: bash version, jq, kimi CLI"
  - "Component modularity: separate functions for MCP, hooks, model tools"
  - "Configuration preservation: don't overwrite existing user configs"
  - "Post-install guidance: clear next steps for users"

# Metrics
duration: 12min
completed: 2026-02-05
---

# Phase 11 Plan 01: Update install.sh for v2.0 Summary

**Enhanced install.sh with complete v2.0 component installation including MCP server, git hooks system, model selection tools, jq dependency checking, dry-run mode, and comprehensive post-installation guidance**

## Performance

- **Duration:** 12 min
- **Started:** 2026-02-05T18:20:00Z
- **Completed:** 2026-02-05T18:32:00Z
- **Tasks:** 2
- **Files modified:** 1

## Accomplishments

- Updated install.sh from v1.0.0 to v2.0.0 (1176 lines, up from 703)
- Added comprehensive jq dependency check with OS-specific installation instructions
- Implemented MCP server installation (kimi-mcp-server, kimi-mcp CLI, kimi-mcp-setup)
- Added model selection tools installation (kimi-model-selector, kimi-cost-estimator)
- Created interactive git hooks installation with --with-hooks flag for automation
- Implemented --dry-run mode for safe installation preview
- Added verify_path() to check PATH configuration and provide guidance
- Created show_summary() with detailed post-installation next steps
- Added backup_config() to preserve existing user configurations
- Updated help text to document all v2.0 features and options
- Maintained full backward compatibility for existing v1.0 users

## Task Commits

1. **Task 1: Add v2.0 component detection and installation** - `7189521` (feat)
   - Version bump to 2.0.0
   - jq dependency check with OS-specific instructions
   - MCP server installation function
   - Model tools installation function
   - Interactive hooks installation with --with-hooks flag
   - Updated help text

2. **Task 2: Add PATH verification and post-install summary** - (included in Task 1)
   - verify_path() function
   - show_summary() function
   - --dry-run mode
   - check_bash_version() function
   - backup_config() function

**Plan metadata:** TBD (docs: complete plan)

## Files Created/Modified

- `install.sh` - Enhanced installer (1176 lines) with:
  - SCRIPT_VERSION="2.0.0"
  - check_jq() - jq dependency validation with platform-specific guidance
  - check_bash_version() - Bash 4.0+ requirement check
  - install_mcp_server() - MCP server and CLI tools installation
  - install_model_tools() - Model selection and cost estimation tools
  - install_hooks_interactive() - Optional git hooks setup
  - verify_path() - PATH configuration verification
  - show_summary() - Post-installation guidance
  - backup_config() - Configuration preservation
  - --dry-run flag - Installation preview mode
  - --with-hooks flag - Automated hooks installation

## Decisions Made

- **Backward compatibility:** All v1.0 installation behavior preserved as default; v2.0 features are additive
- **jq is required:** MCP server functionality requires jq; installer provides clear guidance if missing
- **Interactive by default:** Hooks installation prompts user; --with-hooks flag for automation
- **Preserve user configs:** Existing configuration files are backed up, not overwritten
- **Dry-run for safety:** --dry-run mode allows testing installation without making changes
- **PATH verification:** Installer checks if ~/.local/bin is in PATH and warns if not

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

After installation, users may need to:
1. Install jq if not already present (follow OS-specific instructions from installer)
2. Add ~/.local/bin to PATH if not already configured
3. Run `kimi-mcp-setup install` to register MCP server with Kimi CLI (optional)

## Next Phase Readiness

- Phase 11 (Integration & Distribution) is in progress
- Plan 11-01 complete: install.sh updated for v2.0 ✓
- Ready for Plan 11-02: Update CLAUDE.md with v2.0 commands and delegation patterns
- Remaining Phase 11 plans:
  - 11-02: Update CLAUDE.md
  - 11-03: Create slash commands (/kimi-mcp, /kimi-hooks)
  - 11-04: Create documentation guides

---
*Phase: 11-integration-distribution*
*Completed: 2026-02-05*
