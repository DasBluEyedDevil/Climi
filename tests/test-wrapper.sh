#!/bin/bash

# Test harness for gemini.agent.wrapper.sh
# Uses --dry-run flag to test prompt construction without API calls

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WRAPPER="$SCRIPT_DIR/../skills/gemini.agent.wrapper.sh"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Test helper function
run_test() {
    local name="$1"
    local expected="$2"
    shift 2
    local args=("$@")

    TESTS_RUN=$((TESTS_RUN + 1))

    OUTPUT=$("$WRAPPER" --dry-run "${args[@]}" 2>&1) || true

    if echo "$OUTPUT" | grep -q "$expected"; then
        echo -e "${GREEN}✓${NC} $name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗${NC} $name"
        echo "  Expected to find: $expected"
        echo "  Output was: ${OUTPUT:0:200}..."
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

echo "Running gemini.agent.wrapper.sh tests..."
echo ""

# Test 1: Basic prompt passthrough
run_test "Basic prompt" "Hello world" "Hello world"

# Test 2: Role loading from file
run_test "Role: reviewer" "senior code reviewer" -r reviewer "test query"

# Test 3: Role: security
run_test "Role: security" "security auditor" -r security "test query"

# Test 4: Role: planner
run_test "Role: planner" "technical architect" -r planner "test query"

# Test 5: Template: feature
run_test "Template: feature" "implement a new feature" -t feature "add login"

# Test 6: Template: bug
run_test "Template: bug" "Bug Investigation" -t bug "crash on startup"

# Test 7: Template: verify
run_test "Template: verify" "Verification Request" -t verify "added auth"

# Test 8: Directory inclusion
run_test "Directory flag" "@src/" -d "@src/" "test query"

# Test 9: Schema: issues
run_test "Schema: issues" "severity" --schema issues "find bugs"

# Test 10: Schema: files
run_test "Schema: files" "action" --schema files "what files"

# Test 11: Summarize mode
run_test "Summarize flag" "COMPRESSED" --summarize "test query"

# Test 12: Invalid role error
OUTPUT=$("$WRAPPER" -r nonexistent_role --dry-run "test" 2>&1) || true
if echo "$OUTPUT" | grep -q "Unknown role"; then
    echo -e "${GREEN}✓${NC} Invalid role shows error"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗${NC} Invalid role should show error"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi
TESTS_RUN=$((TESTS_RUN + 1))

# Test 13: Cache TTL option
run_test "Cache TTL flag" "test query" --cache --cache-ttl 3600 "test query"

# Test 14: Retry count option
run_test "Retry flag" "test query" --retry 3 "test query"

# ═══════════════════════════════════════════════════════════
# Parser tests (gemini-parse.sh)
# ═══════════════════════════════════════════════════════════

echo ""
echo "Running gemini-parse.sh tests..."

PARSER="$SCRIPT_DIR/../skills/gemini-parse.sh"

# Test 15: Case-insensitive section parsing (uppercase)
TEST_RESPONSE="## SUMMARY
Test summary

## FILES
test.txt:1 - test file

## ANALYSIS
Test analysis

## RECOMMENDATIONS
1. Test recommendation"

OUTPUT=$(echo "$TEST_RESPONSE" | "$PARSER" --section SUMMARY 2>&1) || true
if echo "$OUTPUT" | grep -q "Test summary"; then
    echo -e "${GREEN}✓${NC} Parser: uppercase SUMMARY section"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗${NC} Parser: uppercase SUMMARY section"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi
TESTS_RUN=$((TESTS_RUN + 1))

# Test 16: Case-insensitive section parsing (lowercase)
TEST_RESPONSE_LOWER="## summary
Test summary lower

## files
test.txt:1 - test file

## analysis
Test analysis

## recommendations
1. Test recommendation"

OUTPUT=$(echo "$TEST_RESPONSE_LOWER" | "$PARSER" --section summary 2>&1) || true
if echo "$OUTPUT" | grep -q "Test summary lower"; then
    echo -e "${GREEN}✓${NC} Parser: lowercase summary section"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗${NC} Parser: lowercase summary section"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi
TESTS_RUN=$((TESTS_RUN + 1))

# Test 17: Parser validation (valid response)
OUTPUT=$(echo "$TEST_RESPONSE" | "$PARSER" --validate 2>&1) || true
if echo "$OUTPUT" | grep -q "valid"; then
    echo -e "${GREEN}✓${NC} Parser: validates correct response"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗${NC} Parser: validates correct response"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi
TESTS_RUN=$((TESTS_RUN + 1))

# Test 18: Parser validation (invalid response)
INVALID_RESPONSE="Just some text without sections"
OUTPUT=$(echo "$INVALID_RESPONSE" | "$PARSER" --validate 2>&1) || true
if echo "$OUTPUT" | grep -q "Missing"; then
    echo -e "${GREEN}✓${NC} Parser: detects missing sections"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗${NC} Parser: detects missing sections"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi
TESTS_RUN=$((TESTS_RUN + 1))

# Test 19: Parser file extraction
OUTPUT=$(echo "$TEST_RESPONSE" | "$PARSER" --files-only 2>&1) || true
if echo "$OUTPUT" | grep -q "test.txt:1"; then
    echo -e "${GREEN}✓${NC} Parser: extracts file references"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗${NC} Parser: extracts file references"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi
TESTS_RUN=$((TESTS_RUN + 1))

# Test 20: Parser JSON output
OUTPUT=$(echo "$TEST_RESPONSE" | "$PARSER" --files-only --json 2>&1) || true
if echo "$OUTPUT" | grep -q '"files"'; then
    echo -e "${GREEN}✓${NC} Parser: JSON output format"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗${NC} Parser: JSON output format"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi
TESTS_RUN=$((TESTS_RUN + 1))

echo ""
echo "════════════════════════════════════════"
echo "Tests: $TESTS_RUN | Passed: $TESTS_PASSED | Failed: $TESTS_FAILED"
echo "════════════════════════════════════════"

if [ $TESTS_FAILED -gt 0 ]; then
    exit 1
fi
