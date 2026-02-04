# Technology Stack

**Analysis Date:** 2026-02-04

## Languages

**Primary:**
- **Bash** (bash 4.0+) - Core wrapper script, all shell utilities
- **PowerShell** (5.0+) - Windows wrapper bridge
- **Markdown** - Role definitions, templates, documentation

**Secondary:**
- **jq** (JSON processor) - Used for JSON parsing/formatting in responses and chat history

## Runtime

**Environment:**
- **Bash Shell** - Primary execution environment (Linux, macOS, Windows Git Bash/WSL)
- **Gemini CLI** (command-line tool) - External API client for Google Gemini

**Package Manager:**
- **None** - Standalone shell scripts with minimal external dependencies
- **Prerequisites installed via OS package managers:**
  - `jq` (required)
  - `bash` (required)
  - `git` (optional, for `--diff` feature)

## Frameworks

**Core:**
- **Gemini CLI** (Google) - LLM API client for code analysis queries
  - Primary model: `gemini-3-pro-preview`
  - Fallback model: `gemini-3-flash-preview`

**Testing:**
- **Bash built-in test framework** - Shell script validation using `grep` and conditional assertions
  - Config: `C:\Users\dasbl\Multi-Agent-Workflow\tests\test-wrapper.sh`
  - Approach: `--dry-run` flag validation without API calls

**Build/Dev:**
- **Bash scripting** - Installation, configuration, execution
- **jq** - JSON processing for structured responses
- **git** - Diff comparison for context (optional)

## Key Dependencies

**Critical:**
- **jq** (JSON command-line processor) - Required for parsing Gemini responses and chat history JSON
  - Used in: `C:\Users\dasbl\Multi-Agent-Workflow\skills\gemini.agent.wrapper.sh` (lines 652, 1013-1018)
  - Critical for: Response parsing, chat session storage

- **Gemini CLI** (Google AI) - Command-line interface to Gemini API
  - Used in: `C:\Users\dasbl\Multi-Agent-Workflow\skills\gemini.agent.wrapper.sh` (line 562)
  - Critical for: All LLM queries, code analysis, research capabilities

**Infrastructure:**
- **bash** (4.0+) - POSIX shell implementation
  - Used in: All `.sh` scripts
  - Features used: Pipefail error handling, array operations, parameter expansion

- **git** (optional) - Version control and diff generation
  - Used in: `C:\Users\dasbl\Multi-Agent-Workflow\skills\gemini.agent.wrapper.sh` (for `--diff` feature)
  - Purpose: Captures git diffs for context-aware analysis

## Configuration

**Environment:**
- Configuration loaded from `.gemini/config` (local) or global `~/.gemini/config`
- All settings can be overridden by command-line flags
- Default configuration example: `C:\Users\dasbl\Multi-Agent-Workflow\.gemini\config.example`

**Key configs available:**
- `VERBOSE` - Enable verbose output (default: false)
- `MODEL` - Gemini model selection (default: gemini-3-pro-preview)
- `MAX_RETRIES` - Retry attempts on failure (default: 2)
- `CACHE_TTL` - Cache time-to-live in seconds (default: 86400 = 24 hours)
- `CACHE_DIR` - Response cache location (default: `.gemini/cache`)
- `HISTORY_DIR` - Chat history storage (default: `.gemini/history`)
- `SAVE_LAST_RESPONSE` - Store responses for parsing (default: true)
- `LAST_RESPONSE_FILE` - Last response file path (default: `.gemini/last-response.txt`)

**Build:**
- Installation script: `C:\Users\dasbl\Multi-Agent-Workflow\install.sh`
  - Automated setup with prerequisites checking
  - Interactive installation type selection (global/project/custom)
  - Backup creation before overwriting existing installations

- Uninstaller: `C:\Users\dasbl\Multi-Agent-Workflow\uninstall.sh`
  - Removes installed files and configurations

## Platform Requirements

**Development:**
- **Operating Systems:** Linux, macOS, Windows (Git Bash or WSL)
- **Shell:** bash 4.0 or newer
- **Required tools:**
  - `jq` (JSON processor)
  - `Gemini CLI` (must be installed and on PATH)
  - `sed`, `awk`, `grep` (standard Unix utilities)
  - `stat` (with platform-specific handling for file timestamps)

- **Optional tools:**
  - `git` (for `--diff` feature support)

**Production:**
- **Deployment target:** Anywhere bash 4.0+ and Gemini CLI are available
- **API access:** Google Gemini API credentials (configured via Gemini CLI)
- **No external hosting required** - Runs locally with remote API calls only to Gemini

## Cross-Platform Support

**Windows:**
- Git Bash or WSL (bash execution environment)
- PowerShell wrapper at `C:\Users\dasbl\Multi-Agent-Workflow\skills\gemini.ps1`
  - Detects bash installation in standard Git locations
  - Handles Windows path conversion to Unix-style paths
  - Falls back to multiple Git install locations

**macOS/Linux:**
- Native bash support
- Standard Unix utilities

**Line Ending Handling:**
- Scripts handle platform-specific differences in `sed`, `stat`, and line endings
- CRLF/LF conversion handled by Git Bash configuration

---

*Stack analysis: 2026-02-04*
