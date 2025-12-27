#!/bin/bash

# Gemini CLI Wrapper Script - "The Eyes"
# Enhanced version with role-based prompting, templates, and context injection
# Gemini has unlimited context (1M+ tokens) and should be used for all code reading/analysis

set -euo pipefail

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
OUTPUT_SCHEMA=""
BATCH_FILE=""
VERBOSE=false  # Quiet by default for Claude consumption
CHAT_SESSION=""
SMART_CTX_KEYWORDS=""
HISTORY_DIR=".gemini/history"

# Role definitions - Built-in roles
# All roles include structured output instructions for Claude consumption
declare -A ROLES

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

ROLES[reviewer]="You are a senior code reviewer analyzing code for another AI developer. Focus on: code quality, potential bugs, security vulnerabilities, performance issues, and adherence to best practices. Always provide specific file:line references.${ROLE_OUTPUT_FORMAT}"

ROLES[planner]="You are a technical architect providing implementation guidance for another AI developer. Focus on: system design, file organization, component relationships, and implementation strategies. Provide clear step-by-step plans with file paths.${ROLE_OUTPUT_FORMAT}"

ROLES[explainer]="You are a technical expert explaining code to another AI developer. Focus on: how code works, data flow, architecture patterns. Be precise with file:line references.${ROLE_OUTPUT_FORMAT}"

ROLES[debugger]="You are a debugging expert helping another AI developer trace issues. Focus on: error call stacks, root causes, related failure points. Provide specific file:line references and fix recommendations.${ROLE_OUTPUT_FORMAT}"

# Large-context roles
ROLES[auditor]="You are a codebase auditor with access to the ENTIRE codebase, reporting to another AI developer. Identify patterns/anti-patterns across ALL files, code duplication, architectural inconsistencies, tech debt. Reference specific files and cross-file relationships.${ROLE_OUTPUT_FORMAT}"

ROLES[migrator]="You are a migration specialist who can see the ENTIRE codebase, planning for another AI developer. Map all affected files, breaking changes, incremental migration paths, hidden dependencies. Provide phased plan with file-by-file changes.${ROLE_OUTPUT_FORMAT}"

ROLES[documenter]="You are a documentation generator with full codebase visibility, creating docs for another AI developer. Analyze public APIs, trace data flows, document component relationships. Output structured markdown.${ROLE_OUTPUT_FORMAT}"

ROLES[security]="You are a security auditor with access to the COMPLETE codebase, reporting to another AI developer. Trace data flows for vulnerabilities, find hardcoded secrets, identify auth gaps, check injection vulnerabilities. Provide severity ratings (CRITICAL/HIGH/MEDIUM/LOW) and file:line references.${ROLE_OUTPUT_FORMAT}"

ROLES[dependency-mapper]="You are a dependency analyst with full codebase visibility, reporting to another AI developer. Map complete dependency graph: internal modules, external packages, circular dependencies, unused imports. Output structured dependency information.${ROLE_OUTPUT_FORMAT}"

ROLES[onboarder]="You are an onboarding guide with access to the entire codebase, briefing another AI developer. Explain: project structure, key architectural decisions, common patterns, important files. Provide structured overview.${ROLE_OUTPUT_FORMAT}"

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

# Function to get role (custom or built-in)
get_role() {
    local role_name="$1"
    
    # Check for custom role in .gemini/roles/
    if [ -f ".gemini/roles/${role_name}.md" ]; then
        cat ".gemini/roles/${role_name}.md"
        echo -e "${CYAN}📋 Loaded custom role: ${role_name}${NC}" >&2
        return 0
    fi
    
    # Fall back to built-in roles
    if [ -n "${ROLES[$role_name]:-}" ]; then
        echo "${ROLES[$role_name]}"
        return 0
    fi
    
    # Role not found
    return 1
}

# Function to find and load GEMINI.md context
load_context() {
    local context=""
    local context_files=(".gemini/GEMINI.md" "GEMINI.md" ".gemini/context.md")
    
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
    --clear-cache          Clear all cached responses
    --schema SCHEMA        Request structured output: files, issues, plan, json
    --batch FILE           Process multiple queries from file (one per line)
    --chat SESSION         Enable conversation mode with session history
    --smart-ctx KEYWORDS   Auto-find context using keywords (grep strategy)
    --verbose              Show status messages (quiet by default for AI consumption)
    --dry-run              Show constructed prompt without executing
    -h, --help             Display this help message

${BLUE}ROLES:${NC}
    ${YELLOW}reviewer${NC}         - Code review focus (quality, bugs, security)
    ${YELLOW}planner${NC}          - Architecture and implementation planning
    ${YELLOW}explainer${NC}        - Code explanation and mentoring
    ${YELLOW}debugger${NC}         - Bug tracing and root cause analysis
    ${CYAN}--- Large-Context Roles (leverage 1M tokens) ---${NC}
    ${YELLOW}auditor${NC}          - Codebase-wide patterns, tech debt, health report
    ${YELLOW}migrator${NC}         - Large-scale migration planning
    ${YELLOW}documenter${NC}       - Comprehensive documentation generation
    ${YELLOW}security${NC}         - Deep security audit across all files
    ${YELLOW}dependency-mapper${NC} - Dependency graph and coupling analysis
    ${YELLOW}onboarder${NC}        - New developer onboarding guide

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
        "$0" ${DIRECTORIES:+-d "$DIRECTORIES"} ${ROLE:+-r "$ROLE"} ${TEMPLATE:+-t "$TEMPLATE"} -m "$MODEL" --no-fallback "$line"
        
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
    ROLE_CONTENT=$(get_role "$ROLE")
    if [ -n "$ROLE_CONTENT" ]; then
        FULL_PROMPT="${FULL_PROMPT}**Your Role**: ${ROLE_CONTENT}

"
    else
        # List available custom roles
        CUSTOM_ROLES=""
        if [ -d ".gemini/roles" ]; then
            CUSTOM_ROLES=$(ls -1 .gemini/roles/*.md 2>/dev/null | xargs -I {} basename {} .md | tr '\n' ', ' | sed 's/,$//')
        fi
        echo -e "${RED}Error: Unknown role '$ROLE'.${NC}"
        echo -e "${YELLOW}Built-in roles: reviewer, planner, explainer, debugger${NC}"
        if [ -n "$CUSTOM_ROLES" ]; then
            echo -e "${YELLOW}Custom roles: $CUSTOM_ROLES${NC}"
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
        # Check if jq is installed for proper JSON parsing
        if command -v jq &> /dev/null; then
            # Format history from JSON structure
            HISTORY_CONTENT=$(jq -r '.[] | "User: \(.user)\nGemini: \(.gemini)\n---"' "$HIST_FILE")
        else
            # Simple fallback if jq is missing (assumes simple structure or pure text log)
            # Warning: This is brittle. Users should install jq.
             echo -e "${YELLOW}⚠ 'jq' not found. Chat history might be parsed incorrectly.${NC}" >&2
             HISTORY_CONTENT=$(cat "$HIST_FILE")
        fi

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

# Generate cache key from prompt hash
CACHE_KEY=""
CACHE_FILE=""
if [ "$USE_CACHE" = true ]; then
    # Create cache directory if needed
    mkdir -p "$CACHE_DIR"
    
    # Generate hash of the full prompt (using md5sum or fallback)
    if command -v md5sum &> /dev/null; then
        CACHE_KEY=$(echo -n "$FULL_PROMPT" | md5sum | cut -d' ' -f1)
    elif command -v md5 &> /dev/null; then
        CACHE_KEY=$(echo -n "$FULL_PROMPT" | md5)
    else
        # Fallback: use first 32 chars of base64 encoded prompt
        CACHE_KEY=$(echo -n "$FULL_PROMPT" | base64 | head -c 32)
    fi
    CACHE_FILE="$CACHE_DIR/${CACHE_KEY}.txt"
    
    # Check if cached response exists
    if [ -f "$CACHE_FILE" ]; then
        [ "$VERBOSE" = true ] && echo -e "${CYAN}📦 Using cached response (hash: ${CACHE_KEY:0:8}...)${NC}"
        cat "$CACHE_FILE"
        [ "$VERBOSE" = true ] && echo -e "${GREEN}════════════════════════════════════════════════════════${NC}"
        [ "$VERBOSE" = true ] && echo -e "${GREEN}✓ Gemini analysis complete (from cache)${NC}"
        [ "$VERBOSE" = true ] && echo -e "${GREEN}════════════════════════════════════════════════════════${NC}"
        exit 0
    fi
fi

# Execute gemini command with model selection and fallback
CMD="$BASE_CMD -m $MODEL"

# Capture output if caching
if [ "$USE_CACHE" = true ]; then
    RESPONSE=$(eval "$CMD" '"$FULL_PROMPT"' 2>&1)
    EXIT_CODE=$?
    echo "$RESPONSE"
else
    eval "$CMD" '"$FULL_PROMPT"'
    EXIT_CODE=$?
fi

# If primary model failed and fallback is enabled, try fallback model
if [ $EXIT_CODE -ne 0 ] && [ "$USE_FALLBACK" = true ] && [ "$MODEL" = "$PRIMARY_MODEL" ]; then
    [ "$VERBOSE" = true ] && echo -e "${YELLOW}⚠ Primary model ($MODEL) failed. Trying fallback model ($FALLBACK_MODEL)...${NC}" >&2
    CMD="$BASE_CMD -m $FALLBACK_MODEL"
    
    if [ "$USE_CACHE" = true ]; then
        RESPONSE=$(eval "$CMD" '"$FULL_PROMPT"' 2>&1)
        EXIT_CODE=$?
        echo "$RESPONSE"
    else
        eval "$CMD" '"$FULL_PROMPT"'
        EXIT_CODE=$?
    fi
    
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
    
    # Create valid JSON entry
    # Escape quotes and backslashes for JSON safety
    SAFE_PROMPT=$(echo "$PROMPT" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g' | sed ':a;N;$!ba;s/\n/\\n/g')
    SAFE_RESPONSE=$(echo "$RESPONSE" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g' | sed ':a;N;$!ba;s/\n/\\n/g')
    
    ENTRY="{\"user\": \"$SAFE_PROMPT\", \"gemini\": \"$SAFE_RESPONSE\", \"timestamp\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\"}"
    
    if [ ! -f "$HIST_FILE" ]; then
        echo "[$ENTRY]" > "$HIST_FILE"
    else
        # Remove closing bracket, add comma, add new entry, add closing bracket
        # This is a bit hacky but works without jq
        # If jq exists, use it for safer appending?
        if command -v jq &> /dev/null; then
             # Use a temporary file to avoid race conditions/corruption
             jq ". + [$ENTRY]" "$HIST_FILE" > "${HIST_FILE}.tmp" && mv "${HIST_FILE}.tmp" "$HIST_FILE"
        else
             sed -i '$d' "$HIST_FILE"
             echo ",$ENTRY]" >> "$HIST_FILE"
        fi
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

exit $EXIT_CODE
