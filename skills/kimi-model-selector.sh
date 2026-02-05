#!/usr/bin/env bash
# kimi-model-selector.sh -- Intelligent model selection engine for Kimi delegation
#
# Usage: ./kimi-model-selector.sh --task "description" --files "file1,file2" --json
#   Or: source kimi-model-selector.sh && select_model_with_confidence "task" "files"
#
# This script implements the core model selection engine with multi-factor scoring
# and confidence calculation. It selects between K2 (routine) and K2.5 (creative)
# based on file extensions, task classification, and code patterns.

set -euo pipefail

# -- Constants ----------------------------------------------------------------
readonly MODEL_SELECTOR_VERSION="1.0.0"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly LIB_DIR="${SCRIPT_DIR}/lib"
readonly TASK_CLASSIFIER="${LIB_DIR}/task-classifier.sh"
readonly MODEL_RULES_FILE="${LIB_DIR}/model-rules.json"

# Exit codes
readonly EXIT_SUCCESS=0
readonly EXIT_INVALID_ARGS=10
readonly EXIT_CONFIG_NOT_FOUND=11

# -- Logging ------------------------------------------------------------------
log_error() { echo "[model-selector] Error: $1" >&2; }
log_warn() { echo "[model-selector] Warning: $1" >&2; }
log_info() { echo "[model-selector] Info: $1" >&2; }

# -- Source Dependencies ------------------------------------------------------
if [[ -f "$TASK_CLASSIFIER" ]]; then
    # shellcheck source=./lib/task-classifier.sh
    source "$TASK_CLASSIFIER"
else
    log_error "Task classifier not found: $TASK_CLASSIFIER"
    exit $EXIT_CONFIG_NOT_FOUND
fi

# -- User Override Detection --------------------------------------------------

# check_user_override()
# Checks for KIMI_FORCE_MODEL environment variable
# Returns:
#   The override model (k2 or k2.5) if set and valid, empty string otherwise
# Logs override usage to stderr
check_user_override() {
    local override="${KIMI_FORCE_MODEL:-}"
    
    if [[ -n "$override" ]]; then
        # Normalize to lowercase for validation
        local normalized
        normalized=$(echo "$override" | tr '[:upper:]' '[:lower:]')
        
        if [[ "$normalized" == "k2" || "$normalized" == "k2.5" || "$normalized" == "k2_5" ]]; then
            # Normalize k2_5 to k2.5
            if [[ "$normalized" == "k2_5" ]]; then
                normalized="k2.5"
            fi
            log_info "User override detected: KIMI_FORCE_MODEL=$override"
            echo "$normalized"
            return 0
        else
            log_warn "Invalid KIMI_FORCE_MODEL value: $override (expected: k2 or k2.5)"
            return 1
        fi
    fi
    
    # No override set
    return 0
}

# -- Model Selection ----------------------------------------------------------

# select_model(task_description, file_paths...)
# Selects the appropriate model based on file extensions and task type
# Arguments:
#   $1 - Task description
#   $@ - File paths (starting from $2)
# Returns:
#   "k2" or "k2.5" - The selected model
select_model() {
    local task_description="$1"
    shift
    local files=("$@")
    
    local k2_score=0
    local k2_5_score=0
    
    # Score based on file extensions
    for file in "${files[@]}"; do
        # Skip empty entries
        [[ -z "$file" ]] && continue
        
        local ext="${file##*.}"
        local model_preference
        model_preference=$(get_model_for_extension "$ext")
        
        # Check pattern overrides first
        local filename
        filename=$(basename "$file")
        local pattern_override
        pattern_override=$(check_pattern_override "$filename" 2>/dev/null || true)
        
        if [[ -n "$pattern_override" ]]; then
            model_preference="$pattern_override"
        fi
        
        if [[ "$model_preference" == "k2.5" ]]; then
            ((k2_5_score++))
        else
            ((k2_score++))
        fi
    done
    
    # Score based on task classification
    local task_type
    task_type=$(classify_task "$task_description")
    
    case "$task_type" in
        routine)
            # Routine tasks strongly favor K2
            ((k2_score += 2))
            ;;
        creative)
            # Creative tasks strongly favor K2.5
            ((k2_5_score += 2))
            ;;
        unknown)
            # Unknown tasks get no bias
            ;;
    esac
    
    # Detect code patterns in files (if readable)
    if [[ ${#files[@]} -gt 0 ]]; then
        local pattern_type
        pattern_type=$(detect_code_patterns "${files[@]}")
        
        case "$pattern_type" in
            component)
                # Component patterns boost K2.5
                ((k2_5_score += 1))
                ;;
            utility)
                # Utility patterns slightly boost K2
                ((k2_score += 1))
                ;;
        esac
    fi
    
    # Return model with higher score (default to k2 on tie)
    if [[ $k2_5_score -gt $k2_score ]]; then
        echo "k2.5"
    else
        echo "k2"
    fi
}

# -- Confidence Calculation ---------------------------------------------------

# calculate_confidence(task_description, file_paths..., selected_model)
# Calculates confidence score (0-100) for the model selection
# Arguments:
#   $1 - Task description
#   $@ - File paths (starting from $2, ending before last)
#   ${!#} - Selected model (last argument)
# Returns:
#   Integer 0-100 representing confidence percentage
calculate_confidence() {
    local task_description="$1"
    shift
    
    # Get the last argument as selected_model
    local selected_model="${!#}"
    
    # Get all but the last argument as files
    local files=()
    if [[ $# -gt 1 ]]; then
        files=("${@:1:$#-1}")
    fi
    
    local confidence=50  # Base confidence
    
    # Check if all files agree on selected_model (+20 if yes)
    if [[ ${#files[@]} -gt 0 ]]; then
        local all_agree=true
        
        for file in "${files[@]}"; do
            [[ -z "$file" ]] && continue
            
            local ext="${file##*.}"
            local file_model
            file_model=$(get_model_for_extension "$ext")
            
            # Check pattern overrides
            local filename
            filename=$(basename "$file")
            local pattern_override
            pattern_override=$(check_pattern_override "$filename" 2>/dev/null || true)
            
            if [[ -n "$pattern_override" ]]; then
                file_model="$pattern_override"
            fi
            
            if [[ "$file_model" != "$selected_model" ]]; then
                all_agree=false
                break
            fi
        done
        
        if $all_agree; then
            confidence=$((confidence + 20))
        fi
    else
        # No files provided - can't check agreement
        all_agree=false
    fi
    
    # Check task classification (+20 if not "unknown")
    local task_type
    task_type=$(classify_task "$task_description")
    
    if [[ "$task_type" != "unknown" ]]; then
        confidence=$((confidence + 20))
    fi
    
    # Check code patterns (+10 if patterns match selected_model)
    if [[ ${#files[@]} -gt 0 ]]; then
        local pattern_type
        pattern_type=$(detect_code_patterns "${files[@]}")
        
        local pattern_matches=false
        case "$pattern_type" in
            component)
                [[ "$selected_model" == "k2.5" ]] && pattern_matches=true
                ;;
            utility)
                [[ "$selected_model" == "k2" ]] && pattern_matches=true
                ;;
        esac
        
        if $pattern_matches; then
            confidence=$((confidence + 10))
        fi
    fi
    
    # Cap at 100, minimum 0
    [[ $confidence -gt 100 ]] && confidence=100
    [[ $confidence -lt 0 ]] && confidence=0
    
    echo "$confidence"
}

# -- Main Selection Pipeline --------------------------------------------------

# select_model_with_confidence(task_description, file_paths...)
# Main pipeline that checks override, selects model, and calculates confidence
# Arguments:
#   $1 - Task description
#   $@ - File paths (starting from $2)
# Returns:
#   JSON: {"model": "k2|k2.5", "confidence": N, "override": true|false}
select_model_with_confidence() {
    local task_description="$1"
    shift
    local files=("$@")
    
    local model
    local confidence
    local override=false
    
    # Check for user override first
    local user_override
    user_override=$(check_user_override)
    
    if [[ -n "$user_override" ]]; then
        model="$user_override"
        override=true
    else
        # Call select_model to get recommendation
        model=$(select_model "$task_description" "${files[@]}")
    fi
    
    # Calculate confidence
    if [[ ${#files[@]} -gt 0 ]]; then
        confidence=$(calculate_confidence "$task_description" "${files[@]}" "$model")
    else
        confidence=$(calculate_confidence "$task_description" "$model")
    fi
    
    # Return JSON
    cat <<EOF
{"model": "$model", "confidence": $confidence, "override": $override}
EOF
}

# -- CLI Interface ------------------------------------------------------------

# show_help()
# Displays usage information
show_help() {
    cat <<EOF
Kimi Model Selector v${MODEL_SELECTOR_VERSION}

Usage: $(basename "$0") [OPTIONS]

Options:
  --task "DESCRIPTION"    Task description to analyze
  --files "FILE1,FILE2"   Comma-separated list of file paths
  --json                  Output results as JSON (default: text)
  --help                  Show this help message

Environment Variables:
  KIMI_FORCE_MODEL        Force model selection (k2 or k2.5)

Examples:
  $(basename "$0") --task "refactor authentication" --files "src/auth.py,src/utils.py" --json
  $(basename "$0") --task "create React component" --files "src/App.tsx" --json
  KIMI_FORCE_MODEL=k2.5 $(basename "$0") --task "any task" --json

Exit Codes:
  0  - Success
  10 - Invalid arguments
  11 - Configuration file not found
EOF
}

# parse_arguments()
# Parses command line arguments
# Sets global variables: TASK_DESCRIPTION, FILES_ARRAY, OUTPUT_JSON
declare -a FILES_ARRAY=()
declare TASK_DESCRIPTION=""
declare OUTPUT_JSON=false

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --task)
                if [[ -n "${2:-}" && ! "${2:-}" =~ ^-- ]]; then
                    TASK_DESCRIPTION="$2"
                    shift 2
                else
                    log_error "--task requires a value"
                    return $EXIT_INVALID_ARGS
                fi
                ;;
            --files)
                if [[ -n "${2:-}" && ! "${2:-}" =~ ^-- ]]; then
                    # Split comma-separated files into array
                    IFS=',' read -ra FILES_ARRAY <<< "$2"
                    shift 2
                else
                    log_error "--files requires a value"
                    return $EXIT_INVALID_ARGS
                fi
                ;;
            --json)
                OUTPUT_JSON=true
                shift
                ;;
            --help|-h)
                show_help
                exit $EXIT_SUCCESS
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                return $EXIT_INVALID_ARGS
                ;;
        esac
    done
    
    # Validate required arguments
    if [[ -z "$TASK_DESCRIPTION" ]]; then
        log_error "--task is required"
        show_help
        return $EXIT_INVALID_ARGS
    fi
    
    return $EXIT_SUCCESS
}

# main()
# Main entry point for CLI execution
main() {
    # Check if model-rules.json exists
    if [[ ! -f "$MODEL_RULES_FILE" ]]; then
        log_error "Model rules file not found: $MODEL_RULES_FILE"
        exit $EXIT_CONFIG_NOT_FOUND
    fi
    
    # Parse arguments
    if ! parse_arguments "$@"; then
        exit $EXIT_INVALID_ARGS
    fi
    
    # Get selection result
    local result
    result=$(select_model_with_confidence "$TASK_DESCRIPTION" "${FILES_ARRAY[@]}")
    
    # Output result
    if $OUTPUT_JSON; then
        echo "$result"
    else
        # Text output
        local model confidence override
        model=$(echo "$result" | jq -r '.model')
        confidence=$(echo "$result" | jq -r '.confidence')
        override=$(echo "$result" | jq -r '.override')
        
        echo "Model: $model"
        echo "Confidence: $confidence%"
        if [[ "$override" == "true" ]]; then
            echo "Override: yes (KIMI_FORCE_MODEL)"
        fi
    fi
    
    exit $EXIT_SUCCESS
}

# -- Export Functions ---------------------------------------------------------
# Make functions available when sourced
export -f check_user_override 2>/dev/null || true
export -f select_model 2>/dev/null || true
export -f calculate_confidence 2>/dev/null || true
export -f select_model_with_confidence 2>/dev/null || true

# Run main if executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
