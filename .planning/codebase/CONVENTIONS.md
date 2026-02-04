# Coding Conventions

**Analysis Date:** 2026-02-04

## Naming Patterns

**Files:**
- Bash scripts: lowercase with hyphens (e.g., `gemini-parse.sh`, `gemini.agent.wrapper.sh`)
- Configuration files: use standard naming (e.g., `config`, `.prettierrc`)
- Markdown documentation: UPPERCASE.md for documentation (e.g., `SKILL.md`, `README.md`)
- Role definitions: lowercase with descriptive names in `roles/` directory (e.g., `reviewer.md`, `debugger.md`, `typescript-expert.md`)

**Functions:**
- Bash: snake_case_with_underscores for all functions
- Examples: `run_test()`, `extract_section()`, `validate_format()`, `load_context()`, `show_spinner()`, `start_spinner()`, `stop_spinner()`

**Variables:**
- Bash: UPPERCASE for constants and configuration (e.g., `PRIMARY_MODEL`, `CACHE_TTL`, `MAX_RETRIES`, `SPINNER_PID`)
- Bash: lowercase with underscores for local variables and loop variables (e.g., `spin`, `i`, `current_hash`, `file_age`)
- Bash: descriptive names with full words, no abbreviations (e.g., `VERBOSE`, `DRY_RUN`, `USE_FALLBACK`)

**Command-line Options:**
- Long flags: double-dash with hyphens (e.g., `--dry-run`, `--cache-ttl`, `--smart-ctx`)
- Short flags: single letter with single dash (e.g., `-d`, `-r`, `-t`, `-m`, `-h`)
- Boolean flags: use positive form (e.g., `--verbose`, not `--quiet`)

## Code Style

**Formatting:**
- Bash scripts use consistent indentation (4 spaces)
- Line length: no enforced limit, but aims for readability
- Shell options: `set -euo pipefail` at top of scripts for safety (exit on error, undefined vars, pipe failures)

**Error Handling:**
- Use `set -e` to exit on first error
- Use `|| true` to suppress expected error exits (e.g., `kill "$SPINNER_PID" 2>/dev/null || true`)
- Redirect stderr to stdout selectively: `2>&1` for capturing, `2>/dev/null` for ignoring
- Check command availability: `if ! command -v jq &> /dev/null; then ... fi`

**Logging:**
- Use colored output consistently:
  - RED: `'\033[0;31m'` for errors
  - GREEN: `'\033[0;32m'` for success
  - YELLOW: `'\033[1;33m'` for warnings
  - BLUE: `'\033[0;34m'` for section headers
  - CYAN: `'\033[0;36m'` for informational messages
  - NC: `'\033[0m'` for reset
- Pattern: `echo -e "${COLOR}Message${NC}"` for colored output
- Informational messages use stderr: `echo "..." >&2`
- Progress indicators use colors: `echo -e "${GREEN}✓${NC} Test name"` for pass, `echo -e "${RED}✗${NC} Test name"` for fail
- Spinner: `printf "\r${CYAN}${spin:$i:1} ${msg}${NC}"` for animated progress

## String Handling

**Quoting:**
- Use double quotes for variables: `"$VARIABLE"`
- Use single quotes for literals that shouldn't expand: `'TMPL'` (heredoc content)
- Use `${VARIABLE:-default}` for optional parameters with defaults
- Use `"${array[@]}"` to expand arrays safely

**Heredoc Usage:**
- For multi-line strings, use heredoc: `cat <<'EOF'` (single quotes prevent expansion)
- For command output, use backticks or `$()` (prefer latter): `$(command)`

## Import Organization

**Sourcing Configuration:**
- Order: Load config from user's home directory (global), then project directory (local)
- Pattern: `[ -f "$CONFIG_FILE" ] && source "$CONFIG_FILE"`
- Comments: Use `# shellcheck source=/dev/null` to suppress shellcheck warnings for dynamic sourcing

## Functions Design

**Size:**
- Functions should be focused and reasonably sized (50-100 lines max)
- Extract common logic into separate functions

**Parameters:**
- Use positional parameters: `$1`, `$2`, etc.
- Document parameters in function comments
- Pattern: `local var="$1"` to capture parameter into local variable

**Return Values:**
- Bash functions return exit codes: 0 for success, non-zero for failure
- Use `exit $EXIT_CODE` to propagate exit codes
- Use `return 1` for function-level failure
- For output data, echo the result and capture with command substitution: `OUTPUT=$("function")`

**Error Handling in Functions:**
- Check boolean flags: `if [ "$VERBOSE" = true ]; then ... fi`
- Check if variables are set: `if [ -n "$VARIABLE" ]; then ... fi`
- Check if files exist: `if [ -f "$FILE" ]; then ... fi`
- Check if directories exist: `if [ -d "$DIR" ]; then ... fi`
- Check command exit: `if ! command -v jq &> /dev/null; then ... fi`

## Arithmetic Operations

**Pattern:**
- Use `$(( expression ))` for arithmetic: `ATTEMPT=$((ATTEMPT + 1))`
- Use `$(expr )` as fallback on limited systems
- Use `bc` for complex math with precision: `echo "scale=4; $ESTIMATED_TOKENS * 0.00000015" | bc`

## Case Statements

**Pattern:**
- Use for multi-branch logic with `case $VAR in ... esac`
- Each case ends with `;;`
- Wildcard case `*)` captures unmatched options
- Example from `gemini.agent.wrapper.sh:362-494`: Full argument parsing with `-d|--dir`, `-a|--all-files`, etc.

## Comments

**When to Comment:**
- Before complex logic blocks
- For non-obvious command sequences
- For important configuration values
- Before function definitions with their purpose
- ShellCheck directives: `# shellcheck source=/dev/null` to suppress specific warnings

**Comment Style:**
- Use `#` for single-line comments
- Align multi-line comments: `# Comment line 1` followed by `# Comment line 2`
- Avoid redundant comments that just repeat code

## Command-line Parsing

**Pattern:**
- Use while loop with shift: `while [[ $# -gt 0 ]]; do case $1 in ... esac; done`
- For options with values: `case $1 in -d|--dir) DIRECTORIES="$2"; shift 2 ;;`
- For boolean flags: `case $1 in --verbose) VERBOSE=true; shift ;;`
- Check for value before consuming: `if [ -n "${2:-}" ] && [[ ! "$2" =~ ^- ]]; then`

## Conditional Logic

**Pattern:**
- Use `[ ... ]` (POSIX) or `[[ ... ]]` (Bash extended) for conditionals
- Prefer `[[ ... ]]` in Bash scripts for regex support: `[[ "$string" =~ ^pattern ]]`
- Use `-z` for empty string check: `if [ -z "$VAR" ]; then`
- Use `-n` for non-empty: `if [ -n "$VAR" ]; then`
- Negate conditions: `if ! command -v; then` or `if [ ! -f "$FILE" ]; then`

## Command Substitution

**Pattern:**
- Use `$()` instead of backticks for better nesting: `OUTPUT=$(echo "test")`
- Suppress output to stderr: `$(command 2>/dev/null)`
- Suppress all output: `$(command &>/dev/null)`

## Special Patterns

**Spinner Implementation:**
- Located in `gemini.agent.wrapper.sh:25-53`
- Uses loop with `i=$(( (i + 1) % 10 ))` to cycle through spinner characters
- Background process: `show_spinner "$msg" & SPINNER_PID=$! disown`
- Kill process: `kill "$SPINNER_PID" 2>/dev/null || true` with proper error handling

**Validation & Checks:**
- Pre-flight checks: Verify dependencies before execution (e.g., `jq`, `gemini` CLI)
- Input validation: Check prompt length against `MAX_PROMPT_LENGTH` before execution
- Resource limits: Prevent prompt explosion with `MAX_PROMPT_LENGTH=1000000`

**Retry Logic:**
- Pattern: Exponential backoff with `DELAY=$((2 ** (ATTEMPT - 1)))`
- Attempt counter: `while [ $ATTEMPT -lt $MAX_RETRIES ] && [ $EXIT_CODE -ne 0 ]; do`
- Sleep between retries: `sleep $DELAY`

## Role Definition Format

**Locations:**
- Project roles: `.gemini/roles/*.md` (customizable per project)
- Global roles: `$GLOBAL_GEMINI_DIR/roles/*.md` (shipped with installer)

**Content Pattern:**
- Title as level-1 heading: `# RoleName`
- Description paragraph(s) explaining the role's purpose and focus areas
- File references in description: `file.ts:LINE` format recommended
- No frontmatter or special structure needed

**Examples:**
- `reviewer.md`: Focuses on code quality, bugs, security, performance
- `planner.md`: Focuses on architecture, file organization, implementation strategy
- `debugger.md`: Focuses on call stacks, root causes, failure points
- `security.md`: Focuses on vulnerabilities, hardcoded secrets, injection flaws

## Output Formatting

**Standard Response Format (appended to all roles):**
All roles receive standardized output format instructions in `ROLE_OUTPUT_FORMAT` (lines 108-121):
```
## SUMMARY
[1-2 sentence overview]

## FILES
[List: path/to/file.ext:LINE - brief description]

## ANALYSIS
[Detailed analysis]

## RECOMMENDATIONS
[Numbered list of actionable items]
```

This ensures consistent, parseable output from Gemini for Claude consumption.

## Template Structure

**Built-in Templates:**
- `feature`: Pre-implementation analysis for new features
- `bug`: Bug investigation with root cause analysis
- `verify`: Post-implementation verification checklist
- `architecture`: System overview and architecture request
- `implement-ready`: Claude-optimized with exact files and patterns
- `fix-ready`: Copy-paste ready bug fixes

**Custom Templates:**
- Location: `.gemini/templates/*.md` (project) or global install directory
- Format: Markdown file with prompt text
- Invocation: `-t template-name "user description"`

## Schema Output Patterns

**Available Schemas:**
- `files`: JSON array of file:action:reason:lines
- `issues`: JSON array with severity, file, line, issue, fix
- `plan`: JSON structure with summary, phases, risks, dependencies
- `json`: User-defined valid JSON output

**Pattern:**
Instructions appended to prompt requesting specific JSON format.

---

*Convention analysis: 2026-02-04*
