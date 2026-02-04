# Codebase Structure

**Analysis Date:** 2026-02-04

## Directory Layout

```
Multi-Agent-Workflow/
├── skills/                         # Core implementation files
│   ├── gemini.agent.wrapper.sh     # Main wrapper script (1060 lines)
│   ├── gemini-parse.sh             # Response parser utility (247 lines)
│   └── Claude-Code-Integration.md  # Integration guide
│
├── .gemini/                        # Gemini configuration & runtime
│   ├── roles/                      # 15 role definitions (user personas)
│   │   ├── reviewer.md
│   │   ├── debugger.md
│   │   ├── planner.md
│   │   ├── security.md
│   │   ├── auditor.md
│   │   ├── explainer.md
│   │   ├── migrator.md
│   │   ├── documenter.md
│   │   ├── dependency-mapper.md
│   │   ├── onboarder.md
│   │   ├── api-designer.md
│   │   ├── database-expert.md
│   │   ├── kotlin-expert.md
│   │   ├── typescript-expert.md
│   │   └── python-expert.md
│   │
│   ├── templates/                  # Custom query templates
│   │   ├── security-audit.md       # OWASP-focused security template
│   │   ├── performance.md          # Performance analysis template
│   │   └── [custom templates]
│   │
│   ├── cache/                      # Auto-created response cache
│   │   └── [hash].json             # Cached responses with TTL
│   │
│   ├── history/                    # Auto-created chat session history
│   │   └── [session-id].json
│   │
│   ├── config                      # Optional configuration file
│   └── GeminiContext.md            # Auto-injected project context
│
├── .claude/                        # Claude Code integration
│   ├── settings.json               # Hooks for Claude Code triggers
│   └── skills/gemini-research/
│       └── SKILL.md                # Claude Code skill definition
│
├── install.sh                      # Interactive installer (360 lines)
├── uninstall.sh                    # Uninstaller script (130 lines)
├── GeminiContext.md                # Global context template
│
├── .planning/
│   └── codebase/                   # GSD planning documents
│       ├── ARCHITECTURE.md
│       └── STRUCTURE.md            # This file
│
├── tests/
│   └── test-wrapper.sh             # Test harness (20 tests, no external deps)
│
├── docs/                           # Documentation (empty in repo)
│
└── README.md                       # Comprehensive user guide
```

## Directory Purposes

**`skills/`:**
- Purpose: Core wrapper and utility scripts for Gemini integration
- Contains: Shell scripts for CLI wrapping, response parsing, integration documentation
- Key files:
  - `gemini.agent.wrapper.sh`: Main orchestration (1060 lines, 500+ functions and patterns)
  - `gemini-parse.sh`: Structured response extraction (247 lines)

**`.gemini/`:**
- Purpose: Runtime configuration, roles, templates, cache, and history for Gemini interactions
- Contains: User personas (roles), query templates, response cache, chat history
- Key files:
  - `roles/*.md`: 15 predefined personas (reviewer, security, planner, etc.)
  - `templates/*.md`: Structured analysis templates (security-audit, performance)
  - `cache/`: Auto-created hash-based response cache with TTL
  - `config`: Optional project-specific defaults for model, retries, cache TTL
  - `GeminiContext.md`: Project context auto-injected into every query

**`.claude/`:**
- Purpose: Integration point for Claude Code IDE
- Contains: Settings hooks, skill definition for Claude Code
- Key files:
  - `settings.json`: Hooks to trigger Gemini assistant on keyword detection
  - `skills/gemini-research/SKILL.md`: Teaches Claude when/how to use Gemini wrapper

**`install.sh` / `uninstall.sh`:**
- Purpose: Deployment and lifecycle management
- Responsibilities: Prerequisite checking, installation to ~/.claude/ or project-local, backup creation
- Supports: Global or project-scoped installations

**`tests/`:**
- Purpose: Test harness for wrapper functionality
- Contains: 20 validation tests using --dry-run (no API calls)

## Key File Locations

**Entry Points:**

- `skills/gemini.agent.wrapper.sh:1` - Main CLI entry (shebang and initialization)
- `install.sh:1` - Installation workflow entry
- `.claude/skills/gemini-research/SKILL.md:29` - Claude Code integration entry

**Configuration:**

- `GeminiContext.md` - Global context template (auto-injected into every query)
- `.gemini/config` - Optional project configuration (MODEL, MAX_RETRIES, CACHE_TTL)
- `.claude/settings.json` - Claude Code hooks for keyword detection
- `.gemini/roles/*.md` - 15 role definitions (personas for specialized analysis)

**Core Logic:**

- `skills/gemini.agent.wrapper.sh:361-500` - CLI argument parsing loop
- `skills/gemini.agent.wrapper.sh:124-229` - Template retrieval logic
- `skills/gemini.agent.wrapper.sh:231-255` - Role loading with fallback
- `skills/gemini.agent.wrapper.sh:258-278` - Context injection mechanism
- `skills/gemini.agent.wrapper.sh:500-650` - Prompt construction logic
- `skills/gemini.agent.wrapper.sh:650-750` - Cache management (hit/miss/TTL)
- `skills/gemini.agent.wrapper.sh:800-950` - API invocation with retry/fallback
- `skills/gemini.agent.wrapper.sh:950-1060` - Output handling and response saving

**Testing:**

- `tests/test-wrapper.sh:20-80` - 20 unit tests validating argument parsing and feature loading

## Naming Conventions

**Files:**

- Scripts: `kebab-case.sh` (e.g., `gemini.agent.wrapper.sh`, `gemini-parse.sh`)
- Configs: lowercase.json or lowercase.md (e.g., `config`, `GeminiContext.md`)
- Roles/Templates: `kebab-case.md` (e.g., `typescript-expert.md`, `security-audit.md`)
- Test files: `test-*.sh` (e.g., `test-wrapper.sh`)

**Directories:**

- Hidden configuration: `.gemini/`, `.claude/` (hidden from `ls` unless `-a` flag)
- Functional grouping: `roles/`, `templates/`, `cache/`, `history/`, `skills/`
- Auto-created: `cache/`, `history/`, `logs/` (created on first use)

**Function/Variable Names (in bash):**

- Variables: UPPERCASE for constants/config, lowercase for locals
- Functions: verb_noun pattern (e.g., `get_role()`, `load_context()`, `start_spinner()`)
- Internal functions: snake_case with leading underscore (e.g., `_validate_response()`)

## Where to Add New Code

**New Feature (Analysis Capability):**

1. **Add new role** → Create `.gemini/roles/my-role.md`
   - Format: Markdown with persona description and focus areas
   - Example: `.gemini/roles/kotlin-expert.md` (700 lines)

2. **Add new template** → Create `.gemini/templates/my-template.md`
   - Format: Markdown with structured analysis request
   - Example: `.gemini/templates/security-audit.md` (35 lines)

3. **Use from CLI:**
   ```bash
   ./skills/gemini.agent.wrapper.sh -r my-role "analyze my code"
   ./skills/gemini.agent.wrapper.sh -t my-template "feature description"
   ```

**New Utility Function:**

- Location: Add to `skills/gemini.agent.wrapper.sh` before main loop (line 360)
- Pattern: Follow existing function style with comments explaining parameters and behavior
- Example: `parse_directories()`, `build_cache_key()`, `validate_response()`

**Enhanced CLI Option:**

- Argument parsing: Add case statement to main loop `skills/gemini.agent.wrapper.sh:362`
- Variable: Add to default settings section (lines 67-100)
- Documentation: Update usage() function (line 281-357)
- Example: `--estimate`, `--cache`, `--dry-run` already implemented

**Parser Enhancement:**

- Location: `skills/gemini-parse.sh:94-200` for extraction logic
- Pattern: Add new function for specialized parsing, call from main switch statement
- Example: Add `--extract-recommendations` option

**Integration Hook (Claude Code):**

- Location: `.claude/settings.json`
- Pattern: Add new matcher regex to `UserPromptSubmit` hooks
- Example: Add hook for "optimization", "refactor", "cleanup" keywords

**Test Coverage:**

- Location: `tests/test-wrapper.sh:40-150`
- Pattern: Use `run_test()` helper function with test name, expected output, arguments
- Example: `run_test "New feature" "expected text" -r my-role "query"`

## Special Directories

**`.gemini/cache/`:**
- Purpose: Response caching with TTL-based invalidation
- Generated: Yes (created on first cache write)
- Committed: No (`.gitignore` entry recommended)
- Format: One JSON file per cached response, named by sha256 hash of model+prompt
- Cleanup: Manual deletion recommended when --clear-cache invoked

**`.gemini/history/`:**
- Purpose: Chat session history for multi-turn conversations
- Generated: Yes (created on first --chat-session usage)
- Committed: No (contains conversation context, potentially sensitive)
- Format: One JSON file per session, named by session ID

**`.claude/skills/gemini-research/`:**
- Purpose: Claude Code skill definition for IDE integration
- Generated: No (created by installer)
- Committed: Yes (part of installation)
- Structure: SKILL.md markdown with YAML frontmatter defining skill metadata

**`install.sh` Target Directories:**

When installer runs, it copies files to target location:

```
~/.claude/                           # Global installation
├── skills/
│   ├── gemini.agent.wrapper.sh
│   ├── gemini-parse.sh
│   └── gemini.ps1
├── settings.json
└── skills/gemini-research/
    └── SKILL.md

./.                                  # Project installation
├── .claude/                         # Same structure as above
├── .gemini/                         # Same structure as above
```

## Integration Points

**With Claude Code:**
- File: `.claude/settings.json` - Contains hooks for keyword triggers
- Trigger: When Claude Code detects keywords (review, analyze, trace, debug, security, audit, architecture)
- Hook type: `UserPromptSubmit` (suggests using Gemini) and `Stop` (suggests verification)

**With Gemini CLI:**
- Command: `gemini api contents:generateContent --model gemini-3-pro-preview`
- Authentication: Handled by Gemini CLI using `~/.config/gcloud/` or `GEMINI_API_KEY`
- Output format: Markdown text returned from Gemini CLI stdin/stdout

**With Git (Optional):**
- Flag: `--diff [TARGET]` includes git diff in prompt
- Requirement: `git` command must be available in PATH
- Usage: `./skills/gemini.agent.wrapper.sh --diff "Analyze my changes"`

**With Project (Optional):**
- Context file: `GeminiContext.md` auto-injected if present
- Purpose: Embed architectural patterns, naming conventions, constraints
- Format: Markdown describing project rules and expectations

---

*Structure analysis: 2026-02-04*
