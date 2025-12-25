#!/bin/bash

# Gemini CLI Wrapper Script - "The Eyes"
# This script provides a convenient interface to invoke Gemini CLI for code analysis
# Gemini has unlimited context (1M+ tokens) and should be used for all code reading/analysis

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default settings
OUTPUT_FORMAT="text"
USE_CHECKPOINT=false
USE_SANDBOX=false
ALL_FILES=false
DIRECTORIES=""

# Function to display usage
usage() {
    cat << EOF
${GREEN}Gemini CLI Wrapper - The Eyes (Unlimited Context Analyst)${NC}

${BLUE}USAGE:${NC}
    $0 [OPTIONS] "<prompt>"

${BLUE}OPTIONS:${NC}
    -d, --dir DIRS         Directories to include (e.g., "@src/ @lib/")
    -a, --all-files        Include all files in analysis
    -c, --checkpoint       Enable checkpointing (for modifications)
    -s, --sandbox          Use sandbox mode (safe experimentation)
    -o, --output FORMAT    Output format: text, json (default: text)
    -h, --help             Display this help message

${BLUE}EXAMPLES:${NC}
    ${YELLOW}# Analyze authentication implementation${NC}
    $0 -d "@src/ @lib/" "How is authentication implemented? Show file paths and code."

    ${YELLOW}# Trace a bug${NC}
    $0 -d "@src/ @api/" "Error at auth.ts:145. Trace root cause through call stack."

    ${YELLOW}# Architectural review of entire codebase${NC}
    $0 --all-files "Review architecture for security vulnerabilities. Output findings."

    ${YELLOW}# Verify changes after implementation${NC}
    $0 -d "@src/" "Changes: [summary]. Verify architectural consistency."

${BLUE}ROLE IN QUADRUMVIRATE:${NC}
    Gemini is "The Eyes" - unlimited context (1M+ tokens) code analyst
    - Claude NEVER reads large files (>100 lines)
    - Claude ALWAYS asks Gemini to analyze code instead
    - Gemini provides file paths, code excerpts, and recommendations
    - Result: 90-99% token savings for Claude

${BLUE}PROMPT BEST PRACTICES:${NC}
    ✅ Be specific: "How is auth implemented?" vs "How does this work?"
    ✅ Request structure: "Provide: 1) file paths, 2) code excerpts, 3) recommendations"
    ✅ Include context: "Bug: 401 error at line 145. Trace token validation flow."
    ✅ Ask for recommendations: "Show current pattern AND recommend best approach."

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
        -h|--help)
            usage
            ;;
        *)
            PROMPT="$1"
            shift
            ;;
    esac
done

# Validate prompt
if [ -z "$PROMPT" ]; then
    echo -e "${RED}Error: Prompt is required${NC}"
    usage
fi

# Check if gemini CLI is available
if ! command -v gemini &> /dev/null; then
    echo -e "${RED}Error: gemini CLI not found. Please install Gemini CLI.${NC}"
    echo -e "${YELLOW}Installation: Visit https://ai.google.dev/gemini-api/docs/cli${NC}"
    exit 1
fi

# Build the command
CMD="gemini"

if [ "$ALL_FILES" = true ]; then
    CMD="$CMD --all-files"
fi

if [ "$USE_CHECKPOINT" = true ]; then
    CMD="$CMD -c"
fi

if [ "$USE_SANDBOX" = true ]; then
    CMD="$CMD -s"
fi

if [ "$OUTPUT_FORMAT" != "text" ]; then
    CMD="$CMD -o $OUTPUT_FORMAT"
fi

# Build the full prompt with directories if specified
FULL_PROMPT="$PROMPT"
if [ -n "$DIRECTORIES" ]; then
    FULL_PROMPT="$DIRECTORIES

$PROMPT"
fi

# Execute
echo -e "${GREEN}╔════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   Gemini CLI - The Eyes (Analyzing...)    ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}Directories:${NC} ${DIRECTORIES:-[all]}"
echo -e "${BLUE}All Files:${NC} $ALL_FILES"
echo -e "${BLUE}Output Format:${NC} $OUTPUT_FORMAT"
echo -e "${BLUE}Checkpoint:${NC} $USE_CHECKPOINT"
echo -e "${BLUE}Sandbox:${NC} $USE_SANDBOX"
echo ""
echo -e "${YELLOW}Prompt:${NC}"
echo "$FULL_PROMPT"
echo ""
echo -e "${GREEN}════════════════════════════════════════════${NC}"
echo ""

# Execute gemini command with positional prompt (not -p flag which is deprecated)
$CMD "$FULL_PROMPT"

EXIT_CODE=$?

echo ""
echo -e "${GREEN}════════════════════════════════════════════${NC}"
if [ $EXIT_CODE -eq 0 ]; then
    echo -e "${GREEN}✓ Gemini analysis complete${NC}"
else
    echo -e "${RED}✗ Gemini analysis failed (exit code: $EXIT_CODE)${NC}"
fi
echo -e "${GREEN}════════════════════════════════════════════${NC}"

exit $EXIT_CODE
