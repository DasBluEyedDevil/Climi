# External Integrations

**Analysis Date:** 2026-02-04

## APIs & External Services

**Google Gemini API:**
- **Service:** Google Gemini LLM API
- **What it's used for:** Code analysis, research, debugging, planning, architecture review
- **SDK/Client:** Gemini CLI (command-line interface)
  - Primary model: `gemini-3-pro-preview`
  - Fallback model: `gemini-3-flash-preview`
- **Auth:** Configured through Gemini CLI authentication (credentials stored outside this project)
- **Context capacity:** 1M+ token context window
- **Integration point:** `C:\Users\dasbl\Multi-Agent-Workflow\skills\gemini.agent.wrapper.sh`
  - Base command construction at line 562
  - API call execution with retry logic (lines 926-1000)

**Google Cloud (implicit):**
- Gemini API runs on Google Cloud infrastructure
- No direct Google Cloud SDK integration
- Authentication managed by Gemini CLI tool

## Data Storage

**Local File Storage Only:**
- Cache storage: `.gemini/cache/` directory
  - Stores API responses by hash (model + prompt)
  - TTL-based expiration (default: 24 hours)
  - Can be manually cleared with `--clear-cache`

- Chat history storage: `.gemini/history/` directory
  - Stores conversation sessions in JSON format
  - File format: `{session_name}.json`
  - Structure: Array of `{user, gemini, timestamp}` objects
  - JSON parsing/manipulation at `C:\Users\dasbl\Multi-Agent-Workflow\skills\gemini.agent.wrapper.sh` lines 652, 1013-1018

- Configuration storage: `.gemini/config` (local project) or `~/.gemini/config` (global)
- Last response storage: `.gemini/last-response.txt` (for parser consumption)
- Role definitions: `.gemini/roles/*.md` (project) or `~/.gemini/roles/*.md` (global)
- Templates: `.gemini/templates/*.md`

**No external databases:**
- This project does not connect to any databases
- All data is stored in local files

## Authentication & Identity

**Auth Provider:**
- **Custom** - Gemini CLI handles authentication
- **Implementation approach:**
  - Gemini CLI manages credentials independently
  - Credentials not stored in this project
  - User configures Gemini CLI authentication through `gemini` command
  - Environment: User's local Gemini CLI configuration

**API Key Management:**
- No API keys stored in project files
- Configured externally via Gemini CLI
- Example config at: `C:\Users\dasbl\Multi-Agent-Workflow\.gemini\config.example`

## Monitoring & Observability

**Error Tracking:**
- **None** - Custom error handling via bash scripts
- Error reporting: Standard output/stderr

**Logs:**
- Optional logging approach:
  - `LOG_FILE` parameter in wrapper (configurable)
  - Chat history captured in JSON at `.gemini/history/`
  - Last response saved to `.gemini/last-response.txt` if `SAVE_LAST_RESPONSE=true`

**Debugging:**
- `--verbose` flag enables status messages and spinner output
- `--dry-run` flag shows constructed prompts without API execution
- `--estimate` flag shows token/cost estimates

## CI/CD & Deployment

**Hosting:**
- **No hosting required** - Standalone shell script suite
- Runs locally in user's development environment
- Makes remote calls to Google Gemini API only

**Installation:**
- Installer script: `C:\Users\dasbl\Multi-Agent-Workflow\install.sh`
  - Checks prerequisites (jq, Gemini CLI, git)
  - Supports global (~/.claude/), project, or custom installation
  - Creates backups before overwriting
- Uninstaller script: `C:\Users\dasbl\Multi-Agent-Workflow\uninstall.sh`

**CI Pipeline:**
- **None** - This is a developer tool, not a deployable service
- Test harness: `C:\Users\dasbl\Multi-Agent-Workflow\tests\test-wrapper.sh`
  - 20 tests covering roles, templates, options
  - Uses `--dry-run` for validation without API calls

## Environment Configuration

**Required env vars:**
- None required explicitly
- All configuration via command-line flags or `.gemini/config` file
- Gemini CLI manages its own authentication environment variables (configured separately)

**Optional settings:**
- `VERBOSE` - Enable verbose output
- `MODEL` - Override Gemini model selection
- `MAX_RETRIES` - Retry count on API failure
- `CACHE_TTL` - Cache expiration time in seconds
- `SAVE_LAST_RESPONSE` - Enable response saving for parsing

**Secrets location:**
- Gemini CLI credentials: Configured outside this project (user's `~/.config/gcloud/` or equivalent)
- No secrets stored in project repositories
- Configuration example template: `C:\Users\dasbl\Multi-Agent-Workflow\.gemini\config.example` (for reference, not secrets)

## Webhooks & Callbacks

**Incoming:**
- None - This is a CLI tool, not a web service

**Outgoing:**
- None - Unidirectional API calls to Gemini
- No callbacks or webhook deliveries

## Context Injection

**GeminiContext File:**
- Location: `C:\Users\dasbl\Multi-Agent-Workflow\GeminiContext.md`
- Auto-injected into every Gemini query
- Contains:
  - Role description (research assistant for Claude Code)
  - Output format requirements (SUMMARY, FILES, ANALYSIS, RECOMMENDATIONS)
  - Guidelines for specificity and actionability

**Project Context Sources:**
- `.gemini/context.md` (project-level overrides)
- `.gemini/GeminiContext.md` (project-level, checked first)
- Automatic context detection at `C:\Users\dasbl\Multi-Agent-Workflow\skills\gemini.agent.wrapper.sh` lines 259-268

## Response Parsing

**Structured Response Parser:**
- Location: `C:\Users\dasbl\Multi-Agent-Workflow\skills\gemini-parse.sh`
- Functions:
  - Extract sections (SUMMARY, FILES, ANALYSIS, RECOMMENDATIONS)
  - JSON output format for programmatic consumption
  - File reference extraction
  - Response validation
- Used by: Claude Code for consuming Gemini analysis results

## Model Selection & Fallback

**Primary model:** `gemini-3-pro-preview`
- Used by default for all queries
- Configuration at `C:\Users\dasbl\Multi-Agent-Workflow\skills\gemini.agent.wrapper.sh` line 64

**Fallback model:** `gemini-3-flash-preview`
- Automatically used if primary fails
- Can be disabled with `--no-fallback` flag
- Configuration at line 65

**Retry logic:**
- Default: 2 retries on API failure
- Exponential backoff: 2s, 4s, 8s delays
- Configurable via `--retry N` or `MAX_RETRIES` in config

---

*Integration audit: 2026-02-04*
