#!/bin/bash

# Codex CLI Wrapper Script - Developer Subagent #1
# This script provides a convenient interface to invoke OpenAI Codex CLI
# for UI/visual work and complex reasoning tasks

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Default settings
MODEL="gpt-5"  # Codex default: fast reasoning model
YOLO_MODE=true  # Default to YOLO mode (bypass approvals)
SANDBOX="danger-full-access"  # Full access for agent tasks
OUTPUT_FORMAT="text"
WORKING_DIR=""
PROMPT_FILE=""  # Optional: read prompt from file
ENABLE_SEARCH=false

# Function to display usage
usage() {
    cat << EOF
${GREEN}Codex CLI Wrapper - Developer Subagent #1 (UI/Visual/Complex Reasoning)${NC}

${BLUE}USAGE:${NC}
    $0 [OPTIONS] "<prompt>"

${BLUE}OPTIONS:${NC}
    -m, --model MODEL          Set the model (default: gpt-5)
                              Options: gpt-5, o3, o3-mini
    --safe-mode               Require approval for operations (disables YOLO)
    --sandbox MODE            Sandbox mode (default: danger-full-access)
                              Options: read-only, workspace-write, danger-full-access
    -o, --output FORMAT       Output format (default: text, options: json, markdown)
    -f, --prompt-file FILE    Read prompt from file (avoids bash escaping issues)
    -C, --working-dir DIR     Set working directory (default: current dir)
    --enable-search           Enable web search capability
    -h, --help                Display this help message

${BLUE}EXAMPLES:${NC}
    ${YELLOW}# Standard UI implementation${NC}
    $0 "IMPLEMENTATION TASK: Create NotificationCenter component..."

    ${YELLOW}# Complex reasoning with o3${NC}
    $0 -m o3 "Optimize mission planning algorithm from O(n²) to O(n log n)"

    ${YELLOW}# Fast mini model for simple tasks${NC}
    $0 -m o3-mini "Fix typo in README.md"

    ${YELLOW}# Safe mode with approvals${NC}
    $0 --safe-mode "Implement feature X (ask before making changes)"

    ${YELLOW}# With working directory${NC}
    $0 -C /path/to/project "Implement feature X"

    ${YELLOW}# Use prompt file (recommended for complex prompts with code blocks)${NC}
    $0 -f /tmp/task.txt

    ${YELLOW}# With web search enabled${NC}
    $0 --enable-search "Research and implement latest React patterns for forms"

${BLUE}ROLE IN QUADRUMVIRATE:${NC}
    Codex is "Developer #1" - UI, visual, and complex reasoning specialist
    - UI/visual component implementation (React, Vue, Svelte, Android, iOS)
    - Complex algorithmic problems (using o3 model)
    - Interactive debugging
    - Visual validation
    - Frontend/React/Next.js/Android work
    - Cross-checks Copilot's work

${BLUE}MODEL SELECTION GUIDE:${NC}
    ${CYAN}gpt-5${NC}           Standard implementation, UI components, bug fixes (default, fast)
    ${CYAN}o3${NC}              Maximum reasoning for complex algorithms, architecture decisions
    ${CYAN}o3-mini${NC}         Fast reasoning for simpler tasks

${BLUE}TASK TEMPLATE:${NC}
    IMPLEMENTATION TASK:

    **Objective**: [Clear, one-line goal]

    **Requirements**:
    - [Requirement 1]
    - [Requirement 2]

    **Acceptance Criteria**:
    - [Success definition]

    **Context from Gemini**:
    [Paste Gemini's analysis]

    **Files to Modify**:
    - file1.tsx: [changes needed]

    **TDD Required**: Yes/No

    **After Completion**:
    1. Run tests
    2. Take screenshots (if UI)
    3. Report: changes, test results, screenshots, issues

${BLUE}CROSS-CHECK TEMPLATE:${NC}
    CODE REVIEW TASK:

    Copilot has implemented [feature].

    **Files Changed**: [list]
    **Changes Summary**: [summary]

    **Review For**:
    1. Logic errors
    2. UI/visual concerns
    3. Edge cases
    4. Code quality

    Take screenshots if UI, run tests, report findings.

EOF
    exit 1
}

# Parse arguments
PROMPT=""
while [[ $# -gt 0 ]]; do
    case $1 in
        -m|--model)
            MODEL="$2"
            shift 2
            ;;
        --safe-mode)
            YOLO_MODE=false
            shift
            ;;
        --sandbox)
            SANDBOX="$2"
            shift 2
            ;;
        -o|--output)
            OUTPUT_FORMAT="$2"
            shift 2
            ;;
        -f|--prompt-file)
            PROMPT_FILE="$2"
            shift 2
            ;;
        -C|--working-dir)
            WORKING_DIR="$2"
            shift 2
            ;;
        --enable-search)
            ENABLE_SEARCH=true
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

# Read prompt from file if specified
if [ -n "$PROMPT_FILE" ]; then
    if [ ! -f "$PROMPT_FILE" ]; then
        echo -e "${RED}Error: Prompt file not found: $PROMPT_FILE${NC}"
        exit 1
    fi
    PROMPT=$(cat "$PROMPT_FILE")
fi

# Validate prompt
if [ -z "$PROMPT" ]; then
    echo -e "${RED}Error: Prompt is required (provide directly or via --prompt-file)${NC}"
    usage
fi

# Check if codex CLI is available
if ! command -v codex &> /dev/null; then
    echo -e "${RED}Error: codex CLI not found.${NC}"
    echo -e "${YELLOW}Installation: npm install -g @openai/codex-cli${NC}"
    echo -e "${YELLOW}Or follow: https://help.openai.com/en/articles/11096431${NC}"
    exit 1
fi

# Build the codex command arguments
CODEX_ARGS=()

# Add model
CODEX_ARGS+=("-m" "$MODEL")

# Add sandbox mode
CODEX_ARGS+=("--sandbox" "$SANDBOX")

# Add approval policy based on YOLO mode
if [ "$YOLO_MODE" = true ]; then
    # YOLO mode: bypass all approvals
    CODEX_ARGS+=("--dangerously-bypass-approvals-and-sandbox")
else
    # Safe mode: require approval on untrusted commands
    CODEX_ARGS+=("-a" "untrusted")
fi

# Add working directory if specified
if [ -n "$WORKING_DIR" ]; then
    CODEX_ARGS+=("-C" "$WORKING_DIR")
else
    # Default to current directory
    CODEX_ARGS+=("-C" "$(pwd)")
fi

# Add search if enabled
if [ "$ENABLE_SEARCH" = true ]; then
    CODEX_ARGS+=("--search")
fi

# Use exec subcommand for non-interactive mode
CODEX_ARGS+=("exec")

# Execute
echo -e "${CYAN}╔════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║   Codex CLI - Developer #1 (Coding...)    ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}Model:${NC} $MODEL"
echo -e "${BLUE}YOLO Mode:${NC} $YOLO_MODE"
echo -e "${BLUE}Sandbox:${NC} $SANDBOX"
echo -e "${BLUE}Output Format:${NC} $OUTPUT_FORMAT"
if [ -n "$WORKING_DIR" ]; then
    echo -e "${BLUE}Working Directory:${NC} $WORKING_DIR"
else
    echo -e "${BLUE}Working Directory:${NC} $(pwd)"
fi
echo -e "${BLUE}Web Search:${NC} $ENABLE_SEARCH"
echo ""
echo -e "${YELLOW}Task Prompt:${NC}"
echo "$PROMPT"
echo ""
echo -e "${CYAN}════════════════════════════════════════════${NC}"
echo ""

# Create temp file for prompt to avoid command-line escaping issues
TEMP_PROMPT="/tmp/codex-prompt-$$.txt"
echo "$PROMPT" > "$TEMP_PROMPT"

# Cleanup function
cleanup() {
    rm -f "$TEMP_PROMPT" 2>/dev/null || true
}

# Set trap to cleanup on exit
trap cleanup EXIT INT TERM

# Execute codex with prompt
# Note: codex exec reads from stdin when prompt is piped
codex "${CODEX_ARGS[@]}" < "$TEMP_PROMPT"

EXIT_CODE=$?

echo ""
echo -e "${CYAN}════════════════════════════════════════════${NC}"
echo -e "${CYAN}Codex Agent execution complete${NC}"
echo -e "${CYAN}════════════════════════════════════════════${NC}"
echo ""

if [ $EXIT_CODE -eq 0 ]; then
    echo -e "${GREEN}✓ Codex implementation complete${NC}"
else
    echo -e "${RED}✗ Codex implementation failed (exit code: $EXIT_CODE)${NC}"
fi
echo -e "${CYAN}════════════════════════════════════════════${NC}"

exit $EXIT_CODE
