# Architecture

**Analysis Date:** 2026-02-04

## Pattern Overview

**Overall:** CLI wrapper pattern with role-based prompt engineering and modular template system

**Key Characteristics:**
- Centralized Gemini CLI wrapper that abstracts API interaction complexity
- Role-based (persona-driven) prompting for specialized analysis workflows
- Template system for structured analysis requests (feature, bug, verify, architecture)
- External configuration and extensibility through markdown files
- Context injection mechanism for project-specific constraints
- Two-tier installation (global or project-local) supporting multi-project environments
- Structured response format standardization for downstream parsing

## Layers

**CLI Interface Layer:**
- Purpose: Parse command-line arguments, manage user-facing interactions
- Location: `skills/gemini.agent.wrapper.sh` (lines 361-500)
- Contains: Argument parsing logic, usage documentation, error handling
- Depends on: Configuration loader, role/template system
- Used by: End users, Claude Code through shell invocation

**Configuration & Context Layer:**
- Purpose: Load settings, context files, and project-specific constraints
- Location: `skills/gemini.agent.wrapper.sh` (lines 14-23), `.gemini/config`, `GeminiContext.md`
- Contains: Config file loading, context injection, default settings
- Depends on: File system
- Used by: Core wrapper to configure behavior

**Role & Template System:**
- Purpose: Provide specialized prompting personas and structured analysis templates
- Location: `.gemini/roles/*.md` (15 role files), `.gemini/templates/*.md` (custom templates)
- Contains: Role definitions (reviewer, debugger, planner, security, auditor, etc.), template queries
- Depends on: File system, template registry
- Used by: Prompt construction layer

**Prompt Construction Layer:**
- Purpose: Assemble final prompt with context, role, template, and user query
- Location: `skills/gemini.agent.wrapper.sh` (lines 124-229, 231-255, 258-278, 500-800)
- Contains: Template retrieval, role loading, context loading, prompt assembly logic
- Depends on: Role system, template system, context loader
- Used by: API invocation layer

**API Invocation Layer:**
- Purpose: Execute Gemini CLI command, handle retries and fallback models
- Location: `skills/gemini.agent.wrapper.sh` (lines 800-950)
- Contains: Model selection, gemini CLI invocation, retry logic with exponential backoff, error handling
- Depends on: Prompt construction layer, cache system
- Used by: Output handling layer

**Cache Layer:**
- Purpose: Store and retrieve responses by model+prompt hash to avoid redundant API calls
- Location: `skills/gemini.agent.wrapper.sh` (lines 650-750), `.gemini/cache/` directory
- Contains: Cache hit/miss logic, TTL management (default 24 hours), cache-key generation
- Depends on: File system
- Used by: API invocation layer

**Response Handling Layer:**
- Purpose: Process, validate, and output Gemini responses
- Location: `skills/gemini.agent.wrapper.sh` (lines 950-1060)
- Contains: Output formatting (text/json), response validation, optional response saving
- Depends on: Parser utility
- Used by: End users

**Parser Utility Layer:**
- Purpose: Extract and parse structured sections from Gemini responses
- Location: `skills/gemini-parse.sh` (lines 93-200)
- Contains: Section extraction (SUMMARY, FILES, ANALYSIS, RECOMMENDATIONS), JSON output, validation
- Depends on: awk/sed
- Used by: Response consumers (Claude Code, other tools)

**Installation & Management Layer:**
- Purpose: Deploy wrapper and dependencies to global or project locations
- Location: `install.sh`, `uninstall.sh`
- Contains: Prerequisite checking, interactive installation, file copying, backup creation
- Depends on: File system, bash utilities
- Used by: Initial setup and maintenance

## Data Flow

**Standard Analysis Workflow:**

1. **User invocation** → `./skills/gemini.agent.wrapper.sh -r reviewer -d "@src/" "Review auth module"`
2. **Argument parsing** → Extract role, directories, prompt, options
3. **Configuration loading** → Read `.gemini/config`, `GeminiContext.md`
4. **Role retrieval** → Load `.gemini/roles/reviewer.md` or global equivalent
5. **Template retrieval** → If -t flag used, load from `.gemini/templates/`
6. **Context injection** → Load project constraints from GeminiContext.md
7. **Prompt assembly** → Combine: context + role + template + directories + user query
8. **Cache check** → Hash prompt+model, check `.gemini/cache/` for recent response
9. **API call** → Execute `gemini api contents:generateContent --model gemini-3-pro-preview` with full prompt
10. **Error handling** → If failure and USE_FALLBACK=true, retry with gemini-3-flash-preview
11. **Response formatting** → Output as text or JSON, optionally save to `.gemini/last-response.txt`
12. **Parser invocation** → User can run `gemini-parse.sh --section FILES response.txt` to extract sections

**Caching Flow:**

1. Hash prompt: `sha256(model + prompt_text)`
2. Check cache: `.gemini/cache/{hash}.json`
3. If cache hit AND within TTL: return cached response
4. If cache miss or TTL expired: call API and store response with timestamp

**Installation Flow:**

1. Prerequisites check (jq, gemini CLI, git optional)
2. User selects: Global (~/.claude/), Project (current dir), or Custom
3. Copy `install.sh` → `skills/gemini.agent.wrapper.sh` and `gemini-parse.sh`
4. Copy role definitions: `.gemini/roles/*.md`
5. Copy templates: `.gemini/templates/*.md`
6. Create `.claude/settings.json` with skill hook
7. Create `.claude/skills/gemini-research/SKILL.md` (Claude Code integration)
8. Optional: backup existing installation

**State Management:**

- **Session state**: None - each invocation is stateless
- **Configuration state**: `.gemini/config`, `.claude/settings.json`
- **Cache state**: `.gemini/cache/` directory with JSON response files
- **Chat history** (optional): `.gemini/history/` for --chat-session mode
- **Log files** (optional): `.gemini/logs/` when --log flag used

## Key Abstractions

**Role (Persona-Driven Prompting):**
- Purpose: Encapsulate specialized analysis perspective (reviewer, security auditor, architect, etc.)
- Examples: `.gemini/roles/reviewer.md`, `.gemini/roles/security.md`, `.gemini/roles/planner.md`
- Pattern: Role file contains markdown narrative of the persona; wrapper appends standardized output format instruction to all roles

**Template (Structured Query Framework):**
- Purpose: Provide pre-structured requests for common analysis scenarios
- Examples: `feature` for pre-implementation, `bug` for debugging, `verify` for post-implementation
- Pattern: Template defines analysis structure as numbered list of questions + context placeholder

**Context (Project Constraints Injection):**
- Purpose: Auto-inject project-specific rules, architectural patterns, constraints into every query
- Examples: `GeminiContext.md`, `.gemini/context.md`
- Pattern: Markdown file loaded and prepended to every prompt to set baseline expectations

**Cache Entry:**
- Purpose: Store response with metadata for TTL-based invalidation
- Pattern: JSON file with `{model, prompt_hash, response_text, timestamp, ttl}`
- Location: `.gemini/cache/{sha256(model+prompt)}.json`

## Entry Points

**CLI Entry Point (Primary):**
- Location: `skills/gemini.agent.wrapper.sh` (shebang line 1, main loop line 361-500)
- Triggers: Direct shell invocation or Claude Code via hooks
- Responsibilities: Argument parsing, configuration loading, workflow orchestration, output formatting

**Installation Entry Point:**
- Location: `install.sh` (line 1)
- Triggers: User runs `./install.sh` during setup
- Responsibilities: Validate prerequisites, guide installation type selection, deploy files, create integration hooks

**Parser Entry Point:**
- Location: `skills/gemini-parse.sh` (line 23-51, lines 94-200)
- Triggers: User or script runs `gemini-parse.sh --section FILES response.txt`
- Responsibilities: Read response file, extract sections, output as text or JSON

**Claude Code Skill Entry Point:**
- Location: `.claude/skills/gemini-research/SKILL.md` (line 29-101)
- Triggers: Claude Code detects relevant keywords in user query
- Responsibilities: Teach Claude when/how to invoke gemini wrapper, document roles and templates

## Error Handling

**Strategy:** Multi-tier retry with fallback model selection and graceful degradation

**Patterns:**

1. **API Failure (gemini CLI not found):**
   - Check: `command -v gemini` at startup
   - Fallback: Display error with installation instructions
   - Retry: User must install Gemini CLI

2. **Model Failure (primary model returns error):**
   - Check: Inspect gemini CLI exit code
   - Fallback: If `USE_FALLBACK=true` (default), retry with `gemini-3-flash-preview`
   - Max retries: 2 by default, configurable with `--retry N`
   - Backoff: Exponential (2s, 4s, 8s between attempts)

3. **Invalid Role/Template:**
   - Check: Test role file exists before appending to prompt
   - Fallback: Display error listing available roles
   - Recovery: User specifies different role or uses no role

4. **Cache Corruption:**
   - Check: Validate cache JSON format
   - Fallback: Skip cache and call API directly
   - Cleanup: Log corruption for debugging

5. **Context File Not Found:**
   - Check: Probe multiple context file locations in order
   - Fallback: Continue with empty context (no injection)
   - Behavior: Non-fatal - warnings logged if VERBOSE=true

## Cross-Cutting Concerns

**Logging:**
- Mechanism: echo to stderr with color codes when VERBOSE=true
- Examples: "📋 Loaded role: reviewer", "📄 Loaded context from: GeminiContext.md"
- Persistence: Optional file logging with `--log FILE` flag

**Validation:**
- Response format validation: `gemini-parse.sh --validate response.txt`
- Section extraction validation: Checks for required headers (SUMMARY, FILES, ANALYSIS, RECOMMENDATIONS)
- Argument validation: Check directory flags exist before passing to Gemini

**Authentication:**
- Mechanism: Gemini CLI manages authentication via `~/.config/gcloud/` or `GEMINI_API_KEY` env var
- Wrapper responsibility: None - delegates entirely to Gemini CLI

**Model Selection:**
- Primary: `gemini-3-pro-preview` (high quality, higher cost)
- Fallback: `gemini-3-flash-preview` (lower quality, lower cost)
- Override: `--model MODEL` flag allows user-specified model
- Configuration: Can set `MODEL=` in `.gemini/config`

**Rate Limiting & Caching:**
- Cache strategy: Hash-based with TTL (default 24h, configurable)
- Rate limit mitigation: Re-use cached responses for identical queries
- Smart context: `--smart-ctx KEYWORDS` auto-finds relevant files before querying

---

*Architecture analysis: 2026-02-04*
