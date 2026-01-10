#!/bin/bash

# Gemini CLI Wrapper Script - "The Eyes"
# Enhanced version with role-based prompting, templates, and context injection
# Gemini has unlimited context (1M+ tokens) and should be used for all code reading/analysis

set -euo pipefail

# Load configuration file if it exists (allows setting defaults)
CONFIG_FILE=".gemini/config"
if [ -f "$CONFIG_FILE" ]; then
    # shellcheck source=/dev/null
    source "$CONFIG_FILE"
fi

# Progress spinner for long-running operations
SPINNER_PID=""
show_spinner() {
    local msg="${1:-Waiting for Gemini...}"
    local spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local i=0
    while true; do
        printf "\r${CYAN}${spin:$i:1} ${msg}${NC}"
        i=$(( (i + 1) % 10 ))
        sleep 0.1
    done
}

start_spinner() {
    if [ "$VERBOSE" = true ]; then
        show_spinner "$1" &
        SPINNER_PID=$!
        disown
    fi
}

stop_spinner() {
    if [ -n "$SPINNER_PID" ] && kill -0 "$SPINNER_PID" 2>/dev/null; then
        kill "$SPINNER_PID" 2>/dev/null || true
        wait "$SPINNER_PID" 2>/dev/null || true
        printf "\r"
        SPINNER_PID=""
    fi
}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Model configuration
PRIMARY_MODEL="gemini-3-pro-preview"
FALLBACK_MODEL="gemini-3-flash-preview"

# Default settings
OUTPUT_FORMAT="text"
USE_CHECKPOINT=false
USE_SANDBOX=false
ALL_FILES=false
DIRECTORIES=""
ROLE=""
TEMPLATE=""
DRY_RUN=false
MODEL="$PRIMARY_MODEL"
USE_FALLBACK=true
INCLUDE_DIFF=false
DIFF_TARGET="HEAD"
USE_CACHE=false
CACHE_DIR=".gemini/cache"
CACHE_TTL=86400  # Default: 24 hours (in seconds)
OUTPUT_SCHEMA=""
BATCH_FILE=""
VERBOSE=false  # Quiet by default for Claude consumption
CHAT_SESSION=""
SMART_CTX_KEYWORDS=""
HISTORY_DIR=".gemini/history"
LOG_FILE=""  # Optional log file for debugging
MAX_PROMPT_LENGTH=1000000  # ~1MB limit to prevent resource exhaustion

# New enhancement settings
MAX_RETRIES=2  # Retry count on API failure
ESTIMATE_ONLY=false  # Show token estimate without executing
VALIDATE_RESPONSE=false  # Validate response format after execution
CONTEXT_CHECK=false  # Check for stale context
SUMMARIZE_MODE=false  # Request compressed response
TARGET_FILES=""  # Specific files to include (comma-separated)
DIFF_AWARE=false  # Only include files changed in current branch
SAVE_LAST_RESPONSE=false  # Save response for later parsing
LAST_RESPONSE_FILE=".gemini/last-response.txt"

# Role definitions are loaded from .gemini/roles/*.md files
# The ROLE_OUTPUT_FORMAT is appended to all custom roles automatically
# No built-in roles are hardcoded - all roles are externalized

# Standard output format instruction appended to all roles
ROLE_OUTPUT_FORMAT="

FORMAT YOUR RESPONSE AS:
## SUMMARY
[1-2 sentence overview]

## FILES
[List each relevant file as: path/to/file.ext:LINE - brief description]

## ANALYSIS
[Your detailed analysis]

## RECOMMENDATIONS
[Numbered list of actionable items]"

# Template definitions
get_template() {
    local template_name="$1"
    case "$template_name" in
        feature)
            cat <<'TMPL'
I need to implement a new feature.

Please analyze:
1. Which files will need to be modified? (with line numbers)
2. What existing patterns should I follow?
3. What dependencies or services already exist?
4. Are there similar features I can reference?
5. What risks or edge cases should I consider?

Feature Description:
TMPL
            ;;
        bug)
            cat <<'TMPL'
Bug Investigation Request.

Please trace:
1. Root cause analysis
2. Call stack leading to the issue
3. All affected files with line numbers
4. Similar patterns that might have the same bug
5. Recommended fix approach

Bug Details:
TMPL
            ;;
        verify)
            cat <<'TMPL'
Post-Implementation Verification Request.

Please verify:
1. Architectural consistency with existing patterns
2. No obvious regressions or breaking changes
3. Edge cases are handled
4. Security implications (if applicable)
5. Performance considerations

Provide specific file:line references for any issues found.

Changes Made:
TMPL
            ;;
        architecture)
            cat <<'TMPL'
Architecture Overview Request.

Provide:
1. High-level component organization
2. Key files and their responsibilities
3. Data flow diagram (in mermaid format if possible)
4. Inter-component communication patterns
5. Important design decisions or patterns

Focus Area:
TMPL
            ;;
        implement-ready)
            cat <<'TMPL'
Implementation-Ready Analysis (for Claude Code).

I need to implement this feature. Provide ACTIONABLE output:

1. **Exact files to create/modify** with full paths
2. **Code patterns to follow** - show actual code excerpts I should imitate
3. **Function signatures** I should use (copy-paste ready)
4. **Import statements** needed
5. **Test patterns** to follow

Be extremely specific. Claude Code will implement based on your analysis.

Feature to implement:
TMPL
            ;;
        fix-ready)
            cat <<'TMPL'
Bug Fix Analysis (for Claude Code).

Analyze this bug and provide FIX-READY output:

1. **Root cause file:line** - exact location
2. **Fix code** - show the corrected code
3. **Related files** that may have same issue
4. **Test case** to verify fix

Be extremely specific. Claude Code will apply the fix directly.

Bug details:
TMPL
            ;;
        *)
            # Try loading custom template from .gemini/templates/
            if [ -f ".gemini/templates/${template_name}.md" ]; then
                cat ".gemini/templates/${template_name}.md"
            else
                echo ""
            fi
            ;;
    esac
}

# Function to get role (from .gemini/roles/ directory only)
get_role() {
    local role_name="$1"

    # Check for role in .gemini/roles/
    if [ -f ".gemini/roles/${role_name}.md" ]; then
        cat ".gemini/roles/${role_name}.md"
        # Append standard output format to all roles for Claude consumption
        echo "$ROLE_OUTPUT_FORMAT"
        [ "$VERBOSE" = true ] && echo -e "${CYAN}📋 Loaded role: ${role_name}${NC}" >&2
        return 0
    fi

    # Role not found
    return 1
}

# Function to find and load prompt injection context
load_context() {
    local context=""
    local context_files=(".gemini/GeminiContext.md" "GeminiContext.md" ".gemini/context.md")
    
    for cf in "${context_files[@]}"; do
        if [ -f "$cf" ]; then
            context=$(cat "$cf")
            echo -e "${CYAN}📄 Loaded context from: $cf${NC}" >&2
            break
        fi
    done
    
    echo "$context"
}

# Function to display usage
usage() {
    cat << EOF
${GREEN}Gemini CLI Wrapper - The Eyes (Enhanced Context Manager)${NC}

${BLUE}USAGE:${NC}
    $0 [OPTIONS] "<prompt>"

${BLUE}OPTIONS:${NC}
    -d, --dir DIRS         Directories to include (e.g., "@src/ @lib/")
    -a, --all-files        Include all files in analysis
    -c, --checkpoint       Enable checkpointing (for modifications)
    -s, --sandbox          Use sandbox mode (safe experimentation)
    -o, --output FORMAT    Output format: text, json (default: text)
    -r, --role ROLE        Use a predefined role: reviewer, planner, explainer, debugger
    -t, --template TMPL    Use a query template: feature, bug, verify, architecture
    -m, --model MODEL      Specify model (default: gemini-3-pro-preview)
    --no-fallback          Disable automatic fallback to gemini-3-flash-preview
    --diff [TARGET]        Include git diff in prompt (default: HEAD, or specify commit/branch)
    --cache                Cache response for repeated queries
    --cache-ttl SECONDS    Cache time-to-live in seconds (default: 86400 = 24h)
    --clear-cache          Clear all cached responses
    --schema SCHEMA        Request structured output: files, issues, plan, json
    --batch FILE           Process multiple queries from file (one per line)
    --chat SESSION         Enable conversation mode with session history
    --smart-ctx KEYWORDS   Auto-find context using keywords (grep strategy)
    --verbose              Show status messages (quiet by default for AI consumption)
    --log FILE             Log execution details to file for debugging
    --dry-run              Show constructed prompt without executing
    
    ${CYAN}--- Enhancement Options ---${NC}
    --estimate             Show token/cost estimate without executing
    --validate             Validate response format after execution
    --context-check        Warn if files changed since last query
    --retry N              Retry N times on API failure (default: 2)
    --summarize            Request compressed/shorter response
    --files FILE1,FILE2    Target specific files only
    --diff-aware           Include only files changed in current branch
    --save-response        Save response to .gemini/last-response.txt for parsing
    
    -h, --help             Display this help message

${BLUE}ROLES:${NC}
    Roles are loaded from ${CYAN}.gemini/roles/*.md${NC} files.
    ${YELLOW}Example:${NC} -r reviewer, -r security, -r planner
    Run with an invalid role name to see all available roles.

${BLUE}TEMPLATES:${NC}
    ${YELLOW}feature${NC}     - Pre-implementation analysis for new features
    ${YELLOW}bug${NC}         - Bug investigation and tracing
    ${YELLOW}verify${NC}      - Post-implementation verification
    ${YELLOW}architecture${NC} - System architecture overview

${BLUE}EXAMPLES:${NC}
    ${YELLOW}# Analyze with reviewer role${NC}
    $0 -d "@src/" -r reviewer "Review the authentication module"

    ${YELLOW}# Plan a new feature${NC}
    $0 -d "@src/" -t feature "Add user profile editing"

    ${YELLOW}# Debug an issue${NC}
    $0 -d "@src/" -r debugger "Error at auth.ts:145 - token validation fails"

    ${YELLOW}# Verify changes after implementation${NC}
    $0 -d "@src/" -t verify "Added password reset in auth/reset.ts"

${BLUE}CONTEXT INJECTION:${NC}
    Place a GEMINI.md file in .gemini/ or project root to auto-inject context.
    This file should contain project-specific rules and constraints.

${BLUE}WORKFLOW:${NC}
    1. Gemini analyzes (The Eyes) → provides file paths, code excerpts
    2. Claude implements (The Hands) → writes code based on analysis
    3. Gemini verifies (The Reviewer) → checks for regressions

EOF
    exit 1
}

# Parse arguments
PROMPT=""
while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--dir)
            DIRECTORIES="$2"
            shift 2
            ;;
        -a|--all-files)
            ALL_FILES=true
            shift
            ;;
        -c|--checkpoint)
            USE_CHECKPOINT=true
            shift
            ;;
        -s|--sandbox)
            USE_SANDBOX=true
            shift
            ;;
        -o|--output)
            OUTPUT_FORMAT="$2"
            shift 2
            ;;
        -r|--role)
            ROLE="$2"
            shift 2
            ;;
        -t|--template)
            TEMPLATE="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        -m|--model)
            MODEL="$2"
            USE_FALLBACK=false  # User specified model, don't auto-fallback
            shift 2
            ;;
        --no-fallback)
            USE_FALLBACK=false
            shift
            ;;
        --diff)
            INCLUDE_DIFF=true
            if [ -n "${2:-}" ] && [[ ! "$2" =~ ^- ]]; then
                DIFF_TARGET="$2"
                shift 2
            else
                shift
            fi
            ;;
        --cache)
            USE_CACHE=true
            shift
            ;;
        --cache-ttl)
            CACHE_TTL="$2"
            shift 2
            ;;
        --clear-cache)
            if [ -d "$CACHE_DIR" ]; then
                rm -rf "$CACHE_DIR"/*
                echo -e "${GREEN}✓ Cache cleared${NC}"
            else
                echo -e "${YELLOW}No cache directory found${NC}"
            fi
            exit 0
            ;;
        --schema)
            OUTPUT_SCHEMA="$2"
            shift 2
            ;;
        --batch)
            BATCH_FILE="$2"
            shift 2
            ;;
        --chat)
            CHAT_SESSION="$2"
            shift 2
            ;;
        --smart-ctx)
            SMART_CTX_KEYWORDS="$2"
            shift 2
            ;;
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        --log)
            LOG_FILE="$2"
            shift 2
            ;;
        --estimate)
            ESTIMATE_ONLY=true
            shift
            ;;
        --validate)
            VALIDATE_RESPONSE=true
            shift
            ;;
        --context-check)
            CONTEXT_CHECK=true
            shift
            ;;
        --retry)
            MAX_RETRIES="$2"
            shift 2
            ;;
        --summarize)
            SUMMARIZE_MODE=true
            shift
            ;;
        --files)
            TARGET_FILES="$2"
            shift 2
            ;;
        --diff-aware)
            DIFF_AWARE=true
            shift
            ;;
        --save-response)
            SAVE_LAST_RESPONSE=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            PROMPT="$1"
            shift
            ;;
    esac
done

# Handle batch mode
if [ -n "$BATCH_FILE" ]; then
    if [ ! -f "$BATCH_FILE" ]; then
        echo -e "${RED}Error: Batch file '$BATCH_FILE' not found${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║   Gemini CLI - Batch Processing Mode                   ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${BLUE}Batch file:${NC} $BATCH_FILE"
    echo -e "${BLUE}Model:${NC} $MODEL"
    echo -e "${BLUE}Directories:${NC} ${DIRECTORIES:-[all]}"
    echo ""
    
    QUERY_NUM=0
    TOTAL_QUERIES=$(grep -c -v '^$' "$BATCH_FILE" 2>/dev/null || echo 0)
    
    while IFS= read -r line || [ -n "$line" ]; do
        # Skip empty lines and comments
        [[ -z "$line" || "$line" =~ ^# ]] && continue
        
        ((QUERY_NUM++))
        echo -e "${GREEN}════════════════════════════════════════════════════════${NC}"
        echo -e "${CYAN}Query $QUERY_NUM/$TOTAL_QUERIES:${NC} ${line:0:60}..."
        echo -e "${GREEN}════════════════════════════════════════════════════════${NC}"
        echo ""
        
        # Run this script recursively for each query (without batch mode)
        # Use BASH_SOURCE[0] instead of $0 for reliable path resolution
        "${BASH_SOURCE[0]}" ${DIRECTORIES:+-d "$DIRECTORIES"} ${ROLE:+-r "$ROLE"} ${TEMPLATE:+-t "$TEMPLATE"} -m "$MODEL" --no-fallback "$line"
        
        echo ""
    done < "$BATCH_FILE"
    
    echo -e "${GREEN}════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}✓ Batch processing complete ($QUERY_NUM queries)${NC}"
    echo -e "${GREEN}════════════════════════════════════════════════════════${NC}"
    exit 0
fi

# Validate prompt (skip in batch mode)
if [ -z "$PROMPT" ]; then
    echo -e "${RED}Error: Prompt is required${NC}"
    usage
fi

# Check if gemini CLI is available (skip in dry-run)
if [ "$DRY_RUN" = false ] && ! command -v gemini &> /dev/null; then
    echo -e "${RED}Error: gemini CLI not found. Please install Gemini CLI.${NC}"
    echo -e "${YELLOW}Installation: Visit https://ai.google.dev/gemini-api/docs/cli${NC}"
    exit 1
fi

# Check if jq is available (required for JSON handling)
if [ "$DRY_RUN" = false ] && ! command -v jq &> /dev/null; then
    echo -e "${RED}Error: jq is required but not found.${NC}"
    echo -e "${YELLOW}Installation:${NC}"
    echo -e "  ${CYAN}Ubuntu/Debian:${NC} sudo apt-get install jq"
    echo -e "  ${CYAN}macOS:${NC} brew install jq"
    echo -e "  ${CYAN}Windows (Git Bash):${NC} Download from https://stedolan.github.io/jq/download/"
    exit 1
fi

# Build the base command (model added during execution for fallback support)
BASE_CMD="gemini"

if [ "$ALL_FILES" = true ]; then
    BASE_CMD="$BASE_CMD --all-files"
fi

if [ "$USE_CHECKPOINT" = true ]; then
    BASE_CMD="$BASE_CMD -c"
fi

if [ "$USE_SANDBOX" = true ]; then
    BASE_CMD="$BASE_CMD -s"
fi

if [ "$OUTPUT_FORMAT" != "text" ]; then
    BASE_CMD="$BASE_CMD -o $OUTPUT_FORMAT"
fi

# Build the full prompt
FULL_PROMPT=""

# 1. Load context from GEMINI.md if available
CONTEXT=$(load_context)
if [ -n "$CONTEXT" ]; then
    FULL_PROMPT="$CONTEXT

---

"
fi

# 2. Add role system prompt if specified
if [ -n "$ROLE" ]; then
    ROLE_CONTENT=$(get_role "$ROLE" || true)
    if [ -n "$ROLE_CONTENT" ]; then
        FULL_PROMPT="${FULL_PROMPT}**Your Role**: ${ROLE_CONTENT}

"
    else
        # List available roles from .gemini/roles/
        AVAILABLE_ROLES=""
        if [ -d ".gemini/roles" ]; then
            AVAILABLE_ROLES=$(ls -1 .gemini/roles/*.md 2>/dev/null | xargs -I {} basename {} .md | tr '\n' ', ' | sed 's/,$//')
        fi
        echo -e "${RED}Error: Unknown role '$ROLE'.${NC}"
        if [ -n "$AVAILABLE_ROLES" ]; then
            echo -e "${YELLOW}Available roles: $AVAILABLE_ROLES${NC}"
        else
            echo -e "${YELLOW}No roles found. Create roles in .gemini/roles/*.md${NC}"
        fi
        exit 1
    fi
fi

# 3. Add directories if specified


# 3a. Add Smart Context if specified
if [ -n "$SMART_CTX_KEYWORDS" ]; then
    echo -e "${CYAN}🧠 Finding smart context for: '$SMART_CTX_KEYWORDS'${NC}" >&2
    
    # Exclude common ignores and find files containing keywords
    # Limit to top 20 files to avoid token explosion
    SMART_FILES=$(grep -r -l --exclude-dir={.git,.gemini,node_modules,build,dist,.idea} "$SMART_CTX_KEYWORDS" . 2>/dev/null | head -n 20)
    
    if [ -n "$SMART_FILES" ]; then
        FULL_PROMPT="${FULL_PROMPT}
---
**Smart Context** (Files containing '$SMART_CTX_KEYWORDS'):
"
        for FILE in $SMART_FILES; do
            # Read first 100 lines of each file to be safe
            CONTENT=$(head -n 100 "$FILE")
            FULL_PROMPT="${FULL_PROMPT}
File: $FILE
\`\`\`
$CONTENT
\`\`\`
"
        done
        echo -e "${CYAN}✓ Added $(echo "$SMART_FILES" | wc -l) files to context${NC}" >&2
    else
        echo -e "${YELLOW}⚠ No smart context found for keywords${NC}" >&2
    fi
fi

# 3b. Add Chat History if specified
if [ -n "$CHAT_SESSION" ]; then
    mkdir -p "$HISTORY_DIR"
    HIST_FILE="$HISTORY_DIR/${CHAT_SESSION}.json"

    if [ -f "$HIST_FILE" ]; then
        # Format history from JSON structure using jq (required dependency)
        HISTORY_CONTENT=$(jq -r '.[] | "User: \(.user)\nGemini: \(.gemini)\n---"' "$HIST_FILE")

        if [ -n "$HISTORY_CONTENT" ]; then
            FULL_PROMPT="${FULL_PROMPT}

Previous Conversation History:
$HISTORY_CONTENT

(End of History)
---
"
            [ "$VERBOSE" = true ] && echo -e "${CYAN}📜 Loaded chat history from session: $CHAT_SESSION${NC}" >&2
        fi
    fi
fi

# 3c. Add directories if specified
if [ -n "$DIRECTORIES" ]; then
    FULL_PROMPT="${FULL_PROMPT}$DIRECTORIES

"
fi

# 4. Add template if specified
if [ -n "$TEMPLATE" ]; then
    TEMPLATE_CONTENT=$(get_template "$TEMPLATE")
    if [ -z "$TEMPLATE_CONTENT" ]; then
        # List available custom templates
        CUSTOM_TEMPLATES=""
        if [ -d ".gemini/templates" ]; then
            CUSTOM_TEMPLATES=$(ls -1 .gemini/templates/*.md 2>/dev/null | xargs -I {} basename {} .md | tr '\n' ', ' | sed 's/,$//')
        fi
        echo -e "${RED}Error: Unknown template '$TEMPLATE'.${NC}"
        echo -e "${YELLOW}Built-in templates: feature, bug, verify, architecture${NC}"
        if [ -n "$CUSTOM_TEMPLATES" ]; then
            echo -e "${YELLOW}Custom templates: $CUSTOM_TEMPLATES${NC}"
        fi
        exit 1
    fi
    FULL_PROMPT="${FULL_PROMPT}${TEMPLATE_CONTENT}
"
fi

# 5. Add git diff if requested
if [ "$INCLUDE_DIFF" = true ]; then
    if command -v git &> /dev/null && git rev-parse --git-dir &> /dev/null; then
        CHANGED_FILES=$(git diff --name-only "$DIFF_TARGET" 2>/dev/null)
        DIFF_CONTENT=$(git diff "$DIFF_TARGET" 2>/dev/null)
        
        if [ -n "$CHANGED_FILES" ]; then
            FULL_PROMPT="${FULL_PROMPT}
---

**Changed Files** (diff vs ${DIFF_TARGET}):
\`\`\`
${CHANGED_FILES}
\`\`\`

**Full Diff**:
\`\`\`diff
${DIFF_CONTENT}
\`\`\`

"
            echo -e "${CYAN}📝 Included git diff vs ${DIFF_TARGET} ($(echo "$CHANGED_FILES" | wc -l) files)${NC}" >&2
        else
            echo -e "${YELLOW}⚠ No changes found in git diff vs ${DIFF_TARGET}${NC}" >&2
        fi
    else
        echo -e "${YELLOW}⚠ Not in a git repository, --diff ignored${NC}" >&2
    fi
fi

# 6. Add output schema instructions if specified
if [ -n "$OUTPUT_SCHEMA" ]; then
    SCHEMA_INSTRUCTION=""
    case "$OUTPUT_SCHEMA" in
        files)
            SCHEMA_INSTRUCTION="

**OUTPUT FORMAT REQUIRED**: Return your response as a JSON array of affected files:
\`\`\`json
[
  {\"path\": \"path/to/file.ts\", \"action\": \"modify|create|delete\", \"reason\": \"why\", \"lines\": \"1-50\"}
]
\`\`\`
"
            ;;
        issues)
            SCHEMA_INSTRUCTION="

**OUTPUT FORMAT REQUIRED**: Return your response as a JSON array of issues found:
\`\`\`json
[
  {\"severity\": \"critical|high|medium|low\", \"file\": \"path/to/file\", \"line\": 123, \"issue\": \"description\", \"fix\": \"recommendation\"}
]
\`\`\`
"
            ;;
        plan)
            SCHEMA_INSTRUCTION="

**OUTPUT FORMAT REQUIRED**: Return your response as a structured implementation plan:
\`\`\`json
{
  \"summary\": \"brief description\",
  \"phases\": [
    {\"name\": \"Phase 1\", \"files\": [\"file1.ts\"], \"changes\": \"what to do\", \"effort\": \"hours\"}
  ],
  \"risks\": [\"risk 1\", \"risk 2\"],
  \"dependencies\": [\"dep 1\"]
}
\`\`\`
"
            ;;
        json)
            SCHEMA_INSTRUCTION="

**OUTPUT FORMAT REQUIRED**: Return your entire response as valid JSON that can be parsed programmatically. Structure the JSON appropriately for the query.
"
            ;;
        *)
            echo -e "${YELLOW}⚠ Unknown schema '$OUTPUT_SCHEMA', using default output format${NC}" >&2
            ;;
    esac
    
    if [ -n "$SCHEMA_INSTRUCTION" ]; then
        FULL_PROMPT="${FULL_PROMPT}${SCHEMA_INSTRUCTION}"
        echo -e "${CYAN}📊 Requesting structured output: $OUTPUT_SCHEMA${NC}" >&2
    fi
fi

# 7. Add user prompt
FULL_PROMPT="${FULL_PROMPT}${PROMPT}"

# 7a. Handle --summarize (request compressed response) - must be before dry-run
if [ "$SUMMARIZE_MODE" = true ]; then
    FULL_PROMPT="${FULL_PROMPT}

**IMPORTANT: Provide a COMPRESSED response. Be extremely concise. Use bullet points. Omit verbose explanations. Maximum 500 words.**"
fi

# 8. Input validation - prevent resource exhaustion
PROMPT_LENGTH=${#FULL_PROMPT}
if [ $PROMPT_LENGTH -gt $MAX_PROMPT_LENGTH ]; then
    echo -e "${RED}Error: Prompt too large (${PROMPT_LENGTH} chars, max: ${MAX_PROMPT_LENGTH})${NC}"
    echo -e "${YELLOW}Tip: Use more specific directory filters or reduce context${NC}"
    exit 1
fi

# Logging helper function
log_message() {
    if [ -n "$LOG_FILE" ]; then
        echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] $1" >> "$LOG_FILE"
    fi
}

# Log execution start
log_message "=== Gemini CLI Wrapper Start ==="
log_message "Model: $MODEL | Role: ${ROLE:-none} | Template: ${TEMPLATE:-none}"
log_message "Prompt length: $PROMPT_LENGTH chars"

# Display info (only in verbose mode)
if [ "$VERBOSE" = true ]; then
    echo -e "${GREEN}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║   Gemini CLI - The Eyes (Enhanced Context Manager)    ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${BLUE}Directories:${NC} ${DIRECTORIES:-[all]}"
    echo -e "${BLUE}Model:${NC} $MODEL $([ "$USE_FALLBACK" = true ] && echo "(fallback: $FALLBACK_MODEL)" || echo "(no fallback)")"
    echo -e "${BLUE}Role:${NC} ${ROLE:-[none]}"
    echo -e "${BLUE}Template:${NC} ${TEMPLATE:-[none]}"
    echo -e "${BLUE}Output Format:${NC} $OUTPUT_FORMAT"
    echo -e "${BLUE}Context Loaded:${NC} $([ -n "$CONTEXT" ] && echo 'Yes' || echo 'No')"
    echo ""
fi

if [ "$DRY_RUN" = true ]; then
    echo -e "${YELLOW}═══ DRY RUN - Full Prompt ═══${NC}"
    echo ""
    echo "$FULL_PROMPT"
    echo ""
    echo -e "${YELLOW}═══ End of Prompt ═══${NC}"
    echo ""
    echo -e "${CYAN}Command that would run: $BASE_CMD -m $MODEL${NC}"
    exit 0
fi

[ "$VERBOSE" = true ] && echo -e "${GREEN}════════════════════════════════════════════════════════${NC}"
[ "$VERBOSE" = true ] && echo ""

# 9. Handle --estimate (show token estimate without executing)
if [ "$ESTIMATE_ONLY" = true ]; then
    # Approximate: ~4 chars per token for English text
    ESTIMATED_TOKENS=$((PROMPT_LENGTH / 4))
    # Approximate cost (Gemini pricing varies, using rough estimate)
    COST_ESTIMATE=$(echo "scale=4; $ESTIMATED_TOKENS * 0.00000015" | bc 2>/dev/null || echo "N/A")
    
    echo -e "${CYAN}═══ Token Estimate ═══${NC}"
    echo -e "${BLUE}Prompt length:${NC} $PROMPT_LENGTH characters"
    echo -e "${BLUE}Estimated tokens:${NC} ~$ESTIMATED_TOKENS"
    echo -e "${BLUE}Estimated cost:${NC} ~\$$COST_ESTIMATE (varies by model)"
    echo -e "${CYAN}═══════════════════════${NC}"
    exit 0
fi

# 10. Handle --context-check (warn if files changed since last query)
if [ "$CONTEXT_CHECK" = true ]; then
    CONTEXT_HASH_FILE=".gemini/.last-context-hash"
    # Generate hash of included directories/files
    if [ -n "$DIRECTORIES" ]; then
        CURRENT_HASH=$(find $DIRECTORIES -type f -exec md5sum {} \; 2>/dev/null | md5sum | cut -d' ' -f1)
    else
        CURRENT_HASH=$(find . -maxdepth 2 -type f \( -name "*.ts" -o -name "*.js" -o -name "*.py" -o -name "*.kt" \) -exec md5sum {} \; 2>/dev/null | head -100 | md5sum | cut -d' ' -f1)
    fi
    
    if [ -f "$CONTEXT_HASH_FILE" ]; then
        LAST_HASH=$(cat "$CONTEXT_HASH_FILE")
        if [ "$CURRENT_HASH" != "$LAST_HASH" ]; then
            echo -e "${YELLOW}⚠ Context has changed since last query. Files may have been modified.${NC}" >&2
            echo -e "${YELLOW}  Consider re-analyzing if using cached data.${NC}" >&2
        fi
    fi
    
    # Save current hash
    mkdir -p "$(dirname "$CONTEXT_HASH_FILE")"
    echo "$CURRENT_HASH" > "$CONTEXT_HASH_FILE"
fi

# 11. (--summarize now handled before dry-run in step 7a)

# Generate cache key from prompt hash
CACHE_KEY=""
CACHE_FILE=""
if [ "$USE_CACHE" = true ]; then
    # Create cache directory if needed
    mkdir -p "$CACHE_DIR"
    
    # Generate hash of model + prompt (using md5sum or fallback)
    # Include model in hash to prevent serving cached response from different model
    if command -v md5sum &> /dev/null; then
        CACHE_KEY=$(echo -n "${MODEL}:${FULL_PROMPT}" | md5sum | cut -d' ' -f1)
    elif command -v md5 &> /dev/null; then
        CACHE_KEY=$(echo -n "${MODEL}:${FULL_PROMPT}" | md5)
    else
        # Fallback: use first 32 chars of base64 encoded prompt
        CACHE_KEY=$(echo -n "${MODEL}:${FULL_PROMPT}" | base64 | head -c 32)
    fi
    CACHE_FILE="$CACHE_DIR/${CACHE_KEY}.txt"

    # Check if cached response exists and is not expired
    if [ -f "$CACHE_FILE" ]; then
        # Get file age in seconds (cross-platform: try GNU stat, then BSD stat)
        if stat --version &>/dev/null 2>&1; then
            # GNU stat (Linux)
            FILE_AGE=$(( $(date +%s) - $(stat -c %Y "$CACHE_FILE") ))
        else
            # BSD stat (macOS)
            FILE_AGE=$(( $(date +%s) - $(stat -f %m "$CACHE_FILE") ))
        fi

        if [ $FILE_AGE -lt $CACHE_TTL ]; then
            [ "$VERBOSE" = true ] && echo -e "${CYAN}📦 Using cached response (hash: ${CACHE_KEY:0:8}..., age: ${FILE_AGE}s)${NC}"
            cat "$CACHE_FILE"
            [ "$VERBOSE" = true ] && echo -e "${GREEN}════════════════════════════════════════════════════════${NC}"
            [ "$VERBOSE" = true ] && echo -e "${GREEN}✓ Gemini analysis complete (from cache)${NC}"
            [ "$VERBOSE" = true ] && echo -e "${GREEN}════════════════════════════════════════════════════════${NC}"
            exit 0
        else
            [ "$VERBOSE" = true ] && echo -e "${YELLOW}⚠ Cache expired (age: ${FILE_AGE}s > TTL: ${CACHE_TTL}s), refreshing...${NC}" >&2
        fi
    fi
fi

# Execute gemini command with model selection, retry logic, and fallback
CMD="$BASE_CMD -m $MODEL"
log_message "Executing: $CMD"

# Retry loop with exponential backoff
ATTEMPT=0
EXIT_CODE=1
RESPONSE=""

while [ $ATTEMPT -lt $MAX_RETRIES ] && [ $EXIT_CODE -ne 0 ]; do
    ATTEMPT=$((ATTEMPT + 1))

    # Add delay between retries (exponential backoff: 2s, 4s, 8s...)
    if [ $ATTEMPT -gt 1 ]; then
        DELAY=$((2 ** (ATTEMPT - 1)))
        [ "$VERBOSE" = true ] && echo -e "${YELLOW}⚠ Attempt $ATTEMPT/$MAX_RETRIES (waiting ${DELAY}s)...${NC}" >&2
        sleep $DELAY
    fi

    # Start progress spinner in verbose mode
    start_spinner "Calling Gemini API (attempt $ATTEMPT/$MAX_RETRIES)..."

    # Capture output if caching
    if [ "$USE_CACHE" = true ]; then
        RESPONSE=$(eval "$CMD" '"$FULL_PROMPT"' 2>&1)
        EXIT_CODE=$?
        stop_spinner
    else
        RESPONSE=$(eval "$CMD" '"$FULL_PROMPT"' 2>&1)
        EXIT_CODE=$?
        stop_spinner
        echo "$RESPONSE"
    fi

    log_message "Attempt $ATTEMPT: exit code $EXIT_CODE"
done

# Output cached response after retry loop
if [ "$USE_CACHE" = true ] && [ -n "$RESPONSE" ]; then
    echo "$RESPONSE"
fi

# If primary model failed after retries and fallback is enabled, try fallback model
if [ $EXIT_CODE -ne 0 ] && [ "$USE_FALLBACK" = true ] && [ "$MODEL" = "$PRIMARY_MODEL" ]; then
    [ "$VERBOSE" = true ] && echo -e "${YELLOW}⚠ Primary model ($MODEL) failed after $MAX_RETRIES attempts. Trying fallback model ($FALLBACK_MODEL)...${NC}" >&2
    CMD="$BASE_CMD -m $FALLBACK_MODEL"

    # Reset for fallback attempt
    ATTEMPT=0
    while [ $ATTEMPT -lt $MAX_RETRIES ] && [ $EXIT_CODE -ne 0 ]; do
        ATTEMPT=$((ATTEMPT + 1))

        if [ $ATTEMPT -gt 1 ]; then
            DELAY=$((2 ** (ATTEMPT - 1)))
            [ "$VERBOSE" = true ] && echo -e "${YELLOW}⚠ Fallback attempt $ATTEMPT/$MAX_RETRIES (waiting ${DELAY}s)...${NC}" >&2
            sleep $DELAY
        fi

        if [ "$USE_CACHE" = true ]; then
            RESPONSE=$(eval "$CMD" '"$FULL_PROMPT"' 2>&1)
            EXIT_CODE=$?
            echo "$RESPONSE"
        else
            eval "$CMD" '"$FULL_PROMPT"'
            EXIT_CODE=$?
        fi
    done

    [ "$VERBOSE" = true ] && [ $EXIT_CODE -eq 0 ] && echo -e "${CYAN}ℹ Response generated using fallback model: $FALLBACK_MODEL${NC}" >&2
fi

# Save to cache if successful
if [ "$USE_CACHE" = true ] && [ $EXIT_CODE -eq 0 ] && [ -n "$CACHE_FILE" ]; then
    echo "$RESPONSE" > "$CACHE_FILE"
    [ "$VERBOSE" = true ] && echo -e "${CYAN}💾 Response cached (hash: ${CACHE_KEY:0:8}...)${NC}" >&2
fi

# Save to Chat History if successful
if [ -n "$CHAT_SESSION" ] && [ $EXIT_CODE -eq 0 ]; then
    mkdir -p "$HISTORY_DIR"
    HIST_FILE="$HISTORY_DIR/${CHAT_SESSION}.json"

    # Create JSON entry using jq for proper escaping
    TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    if [ ! -f "$HIST_FILE" ]; then
        # Create new history file with first entry
        jq -n --arg user "$PROMPT" --arg gemini "$RESPONSE" --arg ts "$TIMESTAMP" \
            '[{user: $user, gemini: $gemini, timestamp: $ts}]' > "$HIST_FILE"
    else
        # Append to existing history file
        jq --arg user "$PROMPT" --arg gemini "$RESPONSE" --arg ts "$TIMESTAMP" \
            '. + [{user: $user, gemini: $gemini, timestamp: $ts}]' "$HIST_FILE" > "${HIST_FILE}.tmp" \
            && mv "${HIST_FILE}.tmp" "$HIST_FILE"
    fi
    [ "$VERBOSE" = true ] && echo -e "${CYAN}💾 Chat history saved to $CHAT_SESSION${NC}" >&2
fi

if [ "$VERBOSE" = true ]; then
    echo ""
    echo -e "${GREEN}════════════════════════════════════════════════════════${NC}"
    if [ $EXIT_CODE -eq 0 ]; then
        echo -e "${GREEN}✓ Gemini analysis complete${NC}"
    else
        echo -e "${RED}✗ Gemini analysis failed (exit code: $EXIT_CODE)${NC}"
    fi
    echo -e "${GREEN}════════════════════════════════════════════════════════${NC}"
fi

# Save response for later parsing (--save-response)
if [ "$SAVE_LAST_RESPONSE" = true ] && [ $EXIT_CODE -eq 0 ] && [ -n "$RESPONSE" ]; then
    mkdir -p "$(dirname "$LAST_RESPONSE_FILE")"
    echo "$RESPONSE" > "$LAST_RESPONSE_FILE"
    [ "$VERBOSE" = true ] && echo -e "${CYAN}💾 Response saved to $LAST_RESPONSE_FILE${NC}" >&2
fi

# Validate response format (--validate)
if [ "$VALIDATE_RESPONSE" = true ] && [ $EXIT_CODE -eq 0 ]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [ -f "$SCRIPT_DIR/gemini-parse.sh" ]; then
        if [ -n "$RESPONSE" ]; then
            echo "$RESPONSE" | "$SCRIPT_DIR/gemini-parse.sh" --validate >&2
        elif [ -f "$LAST_RESPONSE_FILE" ]; then
            "$SCRIPT_DIR/gemini-parse.sh" --validate "$LAST_RESPONSE_FILE" >&2
        fi
    else
        echo -e "${YELLOW}⚠ gemini-parse.sh not found, skipping validation${NC}" >&2
    fi
fi

# Log completion
log_message "Exit code: $EXIT_CODE"
log_message "=== Gemini CLI Wrapper End ==="

exit $EXIT_CODE
