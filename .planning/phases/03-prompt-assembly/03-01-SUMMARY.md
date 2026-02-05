---
phase: 03-prompt-assembly
plan: 01
subsystem: cli

tags: [bash, templates, prompt-assembly, kimi-cli]

requires:
  - phase: 01-core-wrapper
    provides: Base wrapper script with role resolution and CLI invocation

provides:
  - 6 built-in templates for common Kimi invocation modes
  - Template resolution from project-local and global locations
  - Template content prepending to user prompts via -t flag
  - Missing template error handling with available templates list

affects:
  - Phase 4: Developer Experience (templates can be listed in help)
  - Phase 5: Claude Code Integration (slash commands can use templates)

tech-stack:
  added: []
  patterns:
    - "Two-tier resolution: project-local .kimi/templates/ first, then global"
    - "Template assembly: template content prepended with newline separation"
    - "Exit code 14 for template not found (consistent with role not found pattern)"

key-files:
  created:
    - .kimi/templates/feature.md
    - .kimi/templates/bug.md
    - .kimi/templates/verify.md
    - .kimi/templates/architecture.md
    - .kimi/templates/implement-ready.md
    - .kimi/templates/fix-ready.md
  modified:
    - skills/kimi.agent.wrapper.sh

key-decisions:
  - "Template structure follows Context-Task-Output Format-Constraints sections"
  - "Template variables use Kimi CLI native syntax: ${KIMI_WORK_DIR}, ${KIMI_NOW}, ${KIMI_MODEL}"
  - "Assembly order: Template content → newline separation → User prompt"
  - "Machine-parseable header updated to include template: [kimi:role:template:model]"
  - "Missing template shows error with comma-separated available templates list"

patterns-established:
  - "Template resolution mirrors role resolution pattern for consistency"
  - "Template files are plain markdown, not complex templating engines"
  - "Templates provide mode-specific guidance without hardcoding in wrapper"

duration: 4min
completed: 2026-02-05
---

# Phase 3 Plan 1: Template-Based Prompt Prepending Summary

**6 built-in templates (feature, bug, verify, architecture, implement-ready, fix-ready) with -t flag support for prepending template content to Kimi prompts.**

## Performance

- **Duration:** 4 min
- **Started:** 2026-02-05T03:02:34Z
- **Completed:** 2026-02-05T03:06:56Z
- **Tasks:** 3/3
- **Files modified:** 7 (6 templates + 1 wrapper)

## Accomplishments

- Created 6 template files following standardized Context-Task-Output Format-Constraints structure
- Extended wrapper with template resolution functions (resolve_template, list_available_templates, die_template_not_found)
- Added -t/--template flag to argument parsing with proper error handling
- Implemented template content prepending with proper newline separation
- Updated machine-parseable header to include template information
- Verified missing template produces clear error with available templates list

## Task Commits

1. **Task 1: Create 6 Built-in Templates** - `8b14772` (feat)
2. **Task 2: Extend Wrapper with Template Flag** - `0c62a83` (feat)
3. **Task 3: Implement Template Content Prepending** - `eda1543` (feat)

**Plan metadata:** TBD (docs commit)

## Files Created/Modified

- `.kimi/templates/feature.md` - New feature development template (74 lines)
- `.kimi/templates/bug.md` - Bug investigation and fix template (79 lines)
- `.kimi/templates/verify.md` - Code verification template (81 lines)
- `.kimi/templates/architecture.md` - Design and structure decisions template (98 lines)
- `.kimi/templates/implement-ready.md` - Pre-planned implementation template (69 lines)
- `.kimi/templates/fix-ready.md` - Pre-planned fix template (61 lines)
- `skills/kimi.agent.wrapper.sh` - Extended with template flag support, resolution functions, and prompt assembly logic

## Decisions Made

- **Template structure**: Context-Task-Output Format-Constraints sections provide consistent guidance across all templates
- **Variable substitution**: Use Kimi CLI's native ${VAR} syntax rather than bash substitution to avoid double-substitution issues
- **Assembly order**: Template content → newline → user prompt creates clear separation while maintaining flow
- **Error handling**: Exit code 14 for template not found, consistent with exit code 12 for role not found
- **Header format**: Extended to [kimi:role:template:model] for Phase 5 Claude Code integration

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- All 6 templates exist and load correctly
- Wrapper accepts -t <template> flag without error
- Missing template shows error with available templates list
- Template content is prepended to user prompt (verified by assembly logic)
- All syntax validated and no regressions in existing functionality

Ready for Phase 4: Developer Experience (thinking mode, dry-run, verbose, help output).

---
*Phase: 03-prompt-assembly*
*Completed: 2026-02-05*
