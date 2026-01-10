#!/bin/bash

# Gemini Response Parser
# Extracts structured sections from Gemini CLI wrapper responses
# Designed for Claude Code integration

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Default settings
SECTION=""
JSON_OUTPUT=false
FILES_ONLY=false
VALIDATE=false
INPUT_FILE=""

usage() {
    cat << EOF
${GREEN}Gemini Response Parser${NC}

Parse structured Gemini responses for Claude Code integration.

${CYAN}USAGE:${NC}
    $0 [OPTIONS] [INPUT_FILE]
    echo "response" | $0 [OPTIONS]

${CYAN}OPTIONS:${NC}
    --section NAME     Extract specific section (SUMMARY, FILES, ANALYSIS, RECOMMENDATIONS)
    --json             Output as JSON
    --files-only       Extract only file:line references as a list
    --validate         Check if response follows expected format
    -h, --help         Show this help

${CYAN}EXAMPLES:${NC}
    # Extract files section
    cat response.txt | $0 --section FILES

    # Get all file references as JSON
    $0 --files-only --json response.txt

    # Validate response format
    $0 --validate response.txt

EOF
    exit 1
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --section)
            SECTION="$2"
            shift 2
            ;;
        --json)
            JSON_OUTPUT=true
            shift
            ;;
        --files-only)
            FILES_ONLY=true
            shift
            ;;
        --validate)
            VALIDATE=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            INPUT_FILE="$1"
            shift
            ;;
    esac
done

# Read input from file or stdin
if [ -n "$INPUT_FILE" ] && [ -f "$INPUT_FILE" ]; then
    CONTENT=$(cat "$INPUT_FILE")
elif [ ! -t 0 ]; then
    CONTENT=$(cat)
else
    echo -e "${RED}Error: No input provided${NC}" >&2
    usage
fi

# Function to extract a section (case-insensitive matching)
extract_section() {
    local section_name="$1"
    local content="$2"

    # Match from section header to next section or end (case-insensitive)
    echo "$content" | awk -v section="$section_name" '
        BEGIN { in_section = 0; found = 0 }
        /^## / {
            if (in_section) { in_section = 0 }
            # Case-insensitive comparison: convert both to uppercase
            header = toupper($0)
            target = "^## " toupper(section)
            if (header ~ target) { in_section = 1; found = 1; next }
        }
        in_section { print }
        END { exit !found }
    '
}

# Function to extract file:line references
extract_file_refs() {
    local content="$1"
    
    # Match patterns like:
    # - path/to/file.ext:123
    # - path/to/file.ext:123-456
    # - `path/to/file.ext:123`
    echo "$content" | grep -oE '[a-zA-Z0-9_./-]+\.[a-zA-Z0-9]+:[0-9]+(-[0-9]+)?' | sort -u
}

# Function to validate response format
validate_format() {
    local content="$1"
    local valid=true
    local issues=()

    # Check for required sections (case-insensitive)
    if ! echo "$content" | grep -qi "^## SUMMARY"; then
        issues+=("Missing ## SUMMARY section")
        valid=false
    fi

    if ! echo "$content" | grep -qi "^## FILES"; then
        issues+=("Missing ## FILES section")
        valid=false
    fi

    if ! echo "$content" | grep -qi "^## ANALYSIS"; then
        issues+=("Missing ## ANALYSIS section")
        valid=false
    fi

    if ! echo "$content" | grep -qi "^## RECOMMENDATIONS"; then
        issues+=("Missing ## RECOMMENDATIONS section")
        valid=false
    fi
    
    # Check if FILES section has file references
    local files_section
    files_section=$(extract_section "FILES" "$content" 2>/dev/null || echo "")
    if [ -n "$files_section" ]; then
        local file_refs
        file_refs=$(extract_file_refs "$files_section")
        if [ -z "$file_refs" ]; then
            issues+=("FILES section has no file:line references")
            valid=false
        fi
    fi
    
    # Output results
    if [ "$JSON_OUTPUT" = true ]; then
        local issues_json="[]"
        if [ ${#issues[@]} -gt 0 ]; then
            issues_json=$(printf '%s\n' "${issues[@]}" | jq -R . | jq -s .)
        fi
        echo "{\"valid\": $valid, \"issues\": $issues_json}"
    else
        if [ "$valid" = true ]; then
            echo -e "${GREEN}✓ Response format is valid${NC}"
        else
            echo -e "${RED}✗ Response format issues:${NC}"
            for issue in "${issues[@]}"; do
                echo -e "  - $issue"
            done
        fi
    fi
    
    [ "$valid" = true ]
}

# Main logic
if [ "$VALIDATE" = true ]; then
    validate_format "$CONTENT"
    exit $?
fi

if [ "$FILES_ONLY" = true ]; then
    file_refs=$(extract_file_refs "$CONTENT")
    
    if [ "$JSON_OUTPUT" = true ]; then
        echo "$file_refs" | jq -R . | jq -s '{"files": .}'
    else
        echo "$file_refs"
    fi
    exit 0
fi

if [ -n "$SECTION" ]; then
    section_content=$(extract_section "$SECTION" "$CONTENT")
    
    if [ -z "$section_content" ]; then
        echo -e "${YELLOW}Section '$SECTION' not found${NC}" >&2
        exit 1
    fi
    
    if [ "$JSON_OUTPUT" = true ]; then
        # For FILES section, try to parse file references
        if [ "$SECTION" = "FILES" ]; then
            file_refs=$(extract_file_refs "$section_content")
            echo "$file_refs" | jq -R . | jq -s '{"section": "FILES", "files": .}'
        else
            echo "$section_content" | jq -Rs "{\"section\": \"$SECTION\", \"content\": .}"
        fi
    else
        echo "$section_content"
    fi
    exit 0
fi

# Default: output as-is or convert to JSON
if [ "$JSON_OUTPUT" = true ]; then
    # Parse all sections into JSON
    summary=$(extract_section "SUMMARY" "$CONTENT" 2>/dev/null || echo "")
    files=$(extract_section "FILES" "$CONTENT" 2>/dev/null || echo "")
    analysis=$(extract_section "ANALYSIS" "$CONTENT" 2>/dev/null || echo "")
    recommendations=$(extract_section "RECOMMENDATIONS" "$CONTENT" 2>/dev/null || echo "")
    file_refs=$(extract_file_refs "$CONTENT")
    
    jq -n \
        --arg summary "$summary" \
        --arg files "$files" \
        --arg analysis "$analysis" \
        --arg recommendations "$recommendations" \
        --argjson file_refs "$(echo "$file_refs" | jq -R . | jq -s .)" \
        '{
            summary: $summary,
            files: $files,
            analysis: $analysis,
            recommendations: $recommendations,
            file_references: $file_refs
        }'
else
    echo "$CONTENT"
fi
