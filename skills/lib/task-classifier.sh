#!/usr/bin/env bash
# task-classifier.sh -- Task type classification and model selection functions
# 
# Usage: source task-classifier.sh
#   classify_task "refactor this code"           # Returns: routine
#   classify_task "create a component"           # Returns: creative
#   get_model_for_extension "tsx"                # Returns: k2.5
#   detect_code_patterns "src/App.tsx"           # Returns: component
#
# This library provides intelligent task classification for model selection
# between K2 (routine/backend tasks) and K2.5 (creative/UI tasks).

set -euo pipefail

# -- Constants ----------------------------------------------------------------
readonly TASK_CLASSIFIER_VERSION="1.0.0"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly MODEL_RULES_FILE="${SCRIPT_DIR}/model-rules.json"

# -- Error handling -----------------------------------------------------------
log_error() { echo "[task-classifier] Error: $1" >&2; }
log_warn() { echo "[task-classifier] Warning: $1" >&2; }
log_info() { echo "[task-classifier] Info: $1" >&2; }

# -- Task Classification ------------------------------------------------------

# classify_task(task_description)
# Classifies a task description as "routine", "creative", or "unknown"
# Arguments:
#   $1 - Task description string
# Returns:
#   "routine" - For maintenance, refactoring, testing tasks (K2)
#   "creative" - For feature implementation, UI work (K2.5)
#   "unknown" - When classification is unclear
classify_task() {
    local task_description="$1"
    local task_lower
    
    # Convert to lowercase for case-insensitive matching
    task_lower=$(echo "$task_description" | tr '[:upper:]' '[:lower:]')
    
    # Routine task patterns (K2 appropriate)
    # These are maintenance, refactoring, testing, and debugging tasks
    local routine_patterns
    routine_patterns="refactor|test|testing|fix.*bug|debug|optimize|lint|format"
    routine_patterns="${routine_patterns}|extract.*method|rename|move.*file|cleanup"
    routine_patterns="${routine_patterns}|audit|review|analyze|verify|check|validate"
    routine_patterns="${routine_patterns}|update.*dependency|upgrade|migrate|convert"
    routine_patterns="${routine_patterns}|document|comment|add.*test|write.*test"
    
    # Creative/UI patterns (K2.5 appropriate)
    # These are feature implementation and UI/UX tasks
    local creative_patterns
    creative_patterns="implement.*feature|create.*component|design|ui|ux|interface"
    creative_patterns="${creative_patterns}|style|layout|animation|responsive|theme"
    creative_patterns="${creative_patterns}|component|build.*interface|visual|frontend"
    creative_patterns="${creative_patterns}|color|typography|spacing|alignment|grid"
    creative_patterns="${creative_patterns}|icon|image|asset|media|graphic|svg"
    
    # Check for routine patterns first
    if echo "$task_lower" | grep -Eq "$routine_patterns" 2>/dev/null; then
        echo "routine"
        return 0
    fi
    
    # Check for creative patterns
    if echo "$task_lower" | grep -Eq "$creative_patterns" 2>/dev/null; then
        echo "creative"
        return 0
    fi
    
    # Unable to classify
    echo "unknown"
    return 0
}

# -- Code Pattern Detection ---------------------------------------------------

# detect_code_patterns(file_paths...)
# Analyzes file paths and content to detect code patterns
# Arguments:
#   $@ - One or more file paths
# Returns:
#   "component" - React/Vue/Angular component files
#   "utility" - Utility/helper files
#   "unknown" - Pattern not recognized
detect_code_patterns() {
    local files=("$@")
    local component_score=0
    local utility_score=0
    
    for file in "${files[@]}"; do
        # Skip if file doesn't exist or isn't readable
        [[ -r "$file" ]] || continue
        
        local filename
        filename=$(basename "$file")
        local ext="${file##*.}"
        
        # Check for component file naming patterns
        if [[ "$filename" =~ [Cc]omponent ]]; then
            ((component_score += 2))
        fi
        
        # Check for Vue single-file components
        if [[ "$ext" == "vue" ]]; then
            ((component_score += 3))
        fi
        
        # Check for Svelte components
        if [[ "$ext" == "svelte" ]]; then
            ((component_score += 3))
        fi
        
        # Check for React/JSX components
        if [[ "$ext" == "tsx" || "$ext" == "jsx" ]]; then
            # Read first 50 lines to detect component patterns
            local content
            content=$(head -n 50 "$file" 2>/dev/null || true)
            
            # React component patterns
            if echo "$content" | grep -Eq "export.*(function|const).*Component|export default.*function|class.*extends.*(Component|React.Component)" 2>/dev/null; then
                ((component_score += 3))
            fi
            
            # JSX usage indicates component
            if echo "$content" | grep -q "return.*(<\|jsx\|React.createElement)" 2>/dev/null; then
                ((component_score += 2))
            fi
            
            # Hooks indicate functional component
            if echo "$content" | grep -Eq "useState|useEffect|useContext|useReducer" 2>/dev/null; then
                ((component_score += 2))
            fi
        fi
        
        # Check for CSS modules and styled-components
        if [[ "$file" =~ \.module\.(css|scss|sass|less)$ ]]; then
            ((component_score += 2))
        fi
        
        # Check for styled-components patterns
        if [[ "$ext" == "ts" || "$ext" == "tsx" || "$ext" == "js" || "$ext" == "jsx" ]]; then
            local content
            content=$(head -n 50 "$file" 2>/dev/null || true)
            if echo "$content" | grep -Eq "styled\.|styled\(|createGlobalStyle|css\`" 2>/dev/null; then
                ((component_score += 2))
            fi
        fi
        
        # Utility patterns (boost utility score)
        if [[ "$filename" =~ (util|helper|lib|common|shared|constants|types) ]]; then
            ((utility_score += 2))
        fi
        
        # Test files are utilities
        if [[ "$filename" =~ (\.test\.|\.spec\.|_test\.|_spec\.) ]]; then
            ((utility_score += 3))
        fi
        
        # Pure logic files (no JSX, no React imports)
        if [[ "$ext" == "ts" || "$ext" == "js" ]]; then
            local content
            content=$(head -n 50 "$file" 2>/dev/null || true)
            
            # No React imports suggests utility
            if ! echo "$content" | grep -Eq "(import.*from ['\"]react['\"]|require\(['\"]react['\"]\))" 2>/dev/null; then
                ((utility_score += 1))
            fi
            
            # Export functions suggests utility
            if echo "$content" | grep -Eq "^export (function|const|async function)" 2>/dev/null; then
                ((utility_score += 1))
            fi
        fi
    done
    
    # Determine result based on scores
    if [[ $component_score -gt $utility_score && $component_score -gt 0 ]]; then
        echo "component"
    elif [[ $utility_score -gt 0 ]]; then
        echo "utility"
    else
        echo "unknown"
    fi
}

# -- Model Rules Loading ------------------------------------------------------

# load_model_rules()
# Loads the model-rules.json configuration file
# Returns:
#   JSON content on stdout, or empty string on error
#   Error messages go to stderr
load_model_rules() {
    if [[ ! -f "$MODEL_RULES_FILE" ]]; then
        log_error "Model rules file not found: $MODEL_RULES_FILE"
        return 1
    fi
    
    if [[ ! -r "$MODEL_RULES_FILE" ]]; then
        log_error "Model rules file not readable: $MODEL_RULES_FILE"
        return 1
    fi
    
    # Validate JSON and output
    if command -v jq >/dev/null 2>&1; then
        jq . "$MODEL_RULES_FILE" 2>/dev/null || {
            log_error "Invalid JSON in model rules file"
            return 1
        }
    else
        # Fallback: just cat the file (assume valid)
        cat "$MODEL_RULES_FILE"
    fi
}

# get_model_for_extension(extension)
# Determines the appropriate model for a file extension
# Arguments:
#   $1 - File extension (with or without leading dot)
# Returns:
#   "k2" - For backend/routine file types
#   "k2.5" - For UI/creative file types
#   Default model from rules if extension not found
get_model_for_extension() {
    local extension="$1"
    local rules
    
    # Remove leading dot if present
    extension="${extension#.}"
    
    # Convert to lowercase
    extension=$(echo "$extension" | tr '[:upper:]' '[:lower:]')
    
    # Load rules if available
    if [[ -f "$MODEL_RULES_FILE" && -r "$MODEL_RULES_FILE" ]]; then
        if command -v jq >/dev/null 2>&1; then
            # Check k2.5 extensions first
            local in_k2_5
            in_k2_5=$(jq -r --arg ext "$extension" '
                .extensions["k2.5"] // [] | 
                map(select(. == $ext)) | 
                length
            ' "$MODEL_RULES_FILE" 2>/dev/null || echo "0")
            
            if [[ "$in_k2_5" -gt 0 ]]; then
                echo "k2.5"
                return 0
            fi
            
            # Check k2 extensions
            local in_k2
            in_k2=$(jq -r --arg ext "$extension" '
                .extensions["k2"] // [] | 
                map(select(. == $ext)) | 
                length
            ' "$MODEL_RULES_FILE" 2>/dev/null || echo "0")
            
            if [[ "$in_k2" -gt 0 ]]; then
                echo "k2"
                return 0
            fi
            
            # Return default
            jq -r '.defaults.model // "k2"' "$MODEL_RULES_FILE" 2>/dev/null || echo "k2"
            return 0
        fi
    fi
    
    # Fallback: hardcoded logic if jq not available or rules missing
    case "$extension" in
        tsx|jsx|css|scss|sass|less|vue|svelte|html|htm|svg)
            echo "k2.5"
            ;;
        py|js|ts|go|rs|java|rb|php|cs|cpp|c|h|hpp|swift|kt|scala|sh|bash|zsh|fish|ps1)
            echo "k2"
            ;;
        *)
            echo "k2"  # Default
            ;;
    esac
}

# -- Helper Functions ---------------------------------------------------------

# get_confidence_threshold()
# Returns the configured confidence threshold from model-rules.json
# Returns:
#   Integer threshold value (default: 75)
get_confidence_threshold() {
    if [[ -f "$MODEL_RULES_FILE" && -r "$MODEL_RULES_FILE" ]]; then
        if command -v jq >/dev/null 2>&1; then
            jq -r '.defaults.confidence_threshold // 75' "$MODEL_RULES_FILE" 2>/dev/null
            return 0
        fi
    fi
    echo "75"  # Default
}

# check_pattern_override(filename)
# Checks if a filename matches any pattern override rules
# Arguments:
#   $1 - Filename to check
# Returns:
#   "k2" or "k2.5" if pattern matches, empty otherwise
check_pattern_override() {
    local filename="$1"
    
    if [[ ! -f "$MODEL_RULES_FILE" || ! -r "$MODEL_RULES_FILE" ]]; then
        return 0
    fi
    
    if ! command -v jq >/dev/null 2>&1; then
        return 0
    fi
    
    # Check k2 patterns (test files, etc.)
    local k2_patterns
    k2_patterns=$(jq -r '.patterns["k2"] // [] | .[]' "$MODEL_RULES_FILE" 2>/dev/null)
    
    while IFS= read -r pattern; do
        [[ -z "$pattern" ]] && continue
        # Convert glob pattern to regex
        local regex
        regex=$(echo "$pattern" | sed 's/\*/.*/g' | sed 's/\?/./g')
        if [[ "$filename" =~ $regex ]]; then
            echo "k2"
            return 0
        fi
    done <<< "$k2_patterns"
    
    # Check k2.5 patterns (component files, etc.)
    local k2_5_patterns
    k2_5_patterns=$(jq -r '.patterns["k2.5"] // [] | .[]' "$MODEL_RULES_FILE" 2>/dev/null)
    
    while IFS= read -r pattern; do
        [[ -z "$pattern" ]] && continue
        local regex
        regex=$(echo "$pattern" | sed 's/\*/.*/g' | sed 's/\?/./g')
        if [[ "$filename" =~ $regex ]]; then
            echo "k2.5"
            return 0
        fi
    done <<< "$k2_5_patterns"
}

# -- Export Functions ---------------------------------------------------------
# Make functions available when sourced
export -f classify_task 2>/dev/null || true
export -f detect_code_patterns 2>/dev/null || true
export -f load_model_rules 2>/dev/null || true
export -f get_model_for_extension 2>/dev/null || true
export -f get_confidence_threshold 2>/dev/null || true
export -f check_pattern_override 2>/dev/null || true
