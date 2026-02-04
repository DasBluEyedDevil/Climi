# Testing Patterns

**Analysis Date:** 2026-02-04

## Test Framework

**Framework:**
- **Shell Testing**: Custom bash test harness (no external framework)
- Location: `tests/test-wrapper.sh`
- Approach: Direct invocation with `--dry-run` to test prompt construction without API calls
- Output: Color-coded pass/fail with summary statistics

**Run Commands:**
```bash
./tests/test-wrapper.sh              # Run all tests
```

**Test Execution Pattern:**
- Tests capture output from wrapper script with `--dry-run` flag
- Use `grep -q` to check for expected patterns in output
- Count passes/fails with variables: `TESTS_PASSED`, `TESTS_FAILED`, `TESTS_RUN`

## Test File Organization

**Location:**
- Test file: `tests/test-wrapper.sh`
- Tests both `gemini.agent.wrapper.sh` and `gemini-parse.sh`

**Naming Convention:**
- Test files: lowercase with dash (e.g., `test-wrapper.sh`)
- Test functions: `run_test()` for wrapper tests, standalone bash for parser tests
- Test cases: Descriptive names like "Basic prompt", "Role: reviewer", "Schema: issues"

## Test Structure

**Test Harness Pattern:**
```bash
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
```

**Test Categories:**

### Wrapper Tests (gemini.agent.wrapper.sh)

**Test 1-4: Basic and Role Tests**
- Test: Basic prompt passthrough
- Test: Role loading (reviewer, security, planner)
- Pattern: `run_test "Test name" "expected string" arg1 arg2`
- Example: `run_test "Basic prompt" "Hello world" "Hello world"`

**Test 5-7: Template Tests**
- Test: Template feature, bug, verify injection
- Pattern: Verify template content appears in prompt
- Example: `run_test "Template: feature" "implement a new feature" -t feature "add login"`

**Test 8: Directory Inclusion**
- Test: Directory flag (-d) is properly passed
- Pattern: `run_test "Directory flag" "@src/" -d "@src/" "test query"`

**Test 9-10: Schema Tests**
- Test: Schema instruction injection (--schema issues, --schema files)
- Pattern: Verify schema-specific JSON format markers appear
- Example: `run_test "Schema: issues" "severity" --schema issues "find bugs"`

**Test 11: Summarize Mode**
- Test: Compression request flag
- Pattern: `run_test "Summarize flag" "COMPRESSED" --summarize "test query"`

**Test 12: Error Handling**
- Test: Invalid role shows error message
- Pattern: Direct check for "Unknown role" in stderr output
- Implementation: Uses `|| true` to ignore exit code

**Test 13-14: Configuration Tests**
- Test: Cache and retry flags
- Pattern: Verify flags are included in output
- Example: `run_test "Cache TTL flag" "test query" --cache --cache-ttl 3600 "test query"`

### Parser Tests (gemini-parse.sh)

**Test 15-16: Section Extraction (Case-insensitive)**
```bash
TEST_RESPONSE="## SUMMARY
Test summary

## FILES
test.txt:1 - test file

## ANALYSIS
Test analysis

## RECOMMENDATIONS
1. Test recommendation"

OUTPUT=$(echo "$TEST_RESPONSE" | "$PARSER" --section SUMMARY 2>&1)
if echo "$OUTPUT" | grep -q "Test summary"; then
    echo -e "${GREEN}✓${NC} Parser: uppercase SUMMARY section"
    TESTS_PASSED=$((TESTS_PASSED + 1))
fi
```

**Test 17: Format Validation (Valid Response)**
- Test: Parser validates correct response format
- Pattern: `echo "$TEST_RESPONSE" | "$PARSER" --validate`
- Expected: Output contains "valid"

**Test 18: Format Validation (Invalid Response)**
- Test: Parser detects missing sections
- Pattern: Invalid response without required sections
- Expected: Output contains "Missing"

**Test 19: File Reference Extraction**
- Test: Extract file:line references
- Pattern: `echo "$TEST_RESPONSE" | "$PARSER" --files-only`
- Expected: Output contains "test.txt:1"

**Test 20: JSON Output Format**
- Test: Parser can output JSON format
- Pattern: `echo "$TEST_RESPONSE" | "$PARSER" --files-only --json`
- Expected: Output contains '"files"' (valid JSON)

## Test Execution Summary

**Pattern at End of Tests:**
```bash
echo ""
echo "════════════════════════════════════"
echo "Tests: $TESTS_RUN | Passed: $TESTS_PASSED | Failed: $TESTS_FAILED"
echo "════════════════════════════════════"

if [ $TESTS_FAILED -gt 0 ]; then
    exit 1
fi
```

**Exit Code:**
- Return 0 if all tests pass
- Return 1 if any test fails

## Mock/Stub Patterns

**--dry-run Flag:**
- Purpose: Test prompt construction without making API calls
- Implementation: Option disables `gemini CLI` invocation
- Output: Shows constructed prompt with section headers

**Test Isolation:**
- No real API calls: `--dry-run` prevents network access
- No side effects: Tests don't create cache files or modify state
- Color output: Uses same color scheme as production for consistent output

## Test Data Patterns

**Inline Fixtures:**
- Multi-line test responses defined as bash variables with heredoc
- Pattern: `TEST_RESPONSE="... content ..."` for simple strings
- Example: Test response in lines 104-114 of `test-wrapper.sh`

**Response Structure:**
All test fixtures follow the standard Gemini response format:
```
## SUMMARY
...content...

## FILES
...content...

## ANALYSIS
...content...

## RECOMMENDATIONS
...content...
```

## What is Tested

**Wrapper Script Tests:**
- ✓ Argument parsing and option handling
- ✓ Role file loading and injection
- ✓ Template content injection
- ✓ Directory flag inclusion
- ✓ Schema instruction injection
- ✓ Error handling for invalid roles
- ✓ Configuration flag acceptance

**Parser Script Tests:**
- ✓ Case-insensitive section extraction
- ✓ Format validation (required sections)
- ✓ File reference extraction (path:line pattern)
- ✓ JSON output generation
- ✓ File-only extraction mode

## What is NOT Tested

**Coverage Gaps:**
- ✗ Actual Gemini API calls (intentionally skipped with --dry-run)
- ✗ Cache functionality (no integration tests)
- ✗ Chat history storage (no persistence tests)
- ✗ Context injection from GEMINI.md files (no fixture-based tests)
- ✗ Smart context keyword matching (no integration tests)
- ✗ Git diff inclusion (no integration tests)
- ✗ Retry logic and exponential backoff (tested via code review only)
- ✗ Spinner animation (tested manually only)

**Risk Areas:**
- API interaction logic depends on manual testing
- Integration with external services (Gemini CLI, jq, git) untested
- Error recovery paths not verified by automated tests
- Edge cases in prompt construction not systematically checked

## Test Execution

**Running Tests:**
```bash
cd /c/Users/dasbl/Multi-Agent-Workflow
./tests/test-wrapper.sh
```

**Example Output:**
```
Running gemini.agent.wrapper.sh tests...

✓ Basic prompt
✓ Role: reviewer
✓ Role: security
✓ Role: planner
✓ Template: feature
✓ Template: bug
✓ Template: verify
✓ Directory flag
✓ Schema: issues
✓ Schema: files
✓ Summarize flag
✓ Invalid role shows error
✓ Cache TTL flag
✓ Retry flag

Running gemini-parse.sh tests...

✓ Parser: uppercase SUMMARY section
✓ Parser: lowercase summary section
✓ Parser: validates correct response
✓ Parser: detects missing sections
✓ Parser: extracts file references
✓ Parser: JSON output format

════════════════════════════════════
Tests: 20 | Passed: 20 | Failed: 0
════════════════════════════════════
```

## Test Patterns for New Tests

**Adding a Wrapper Test:**
```bash
run_test "Description" "expected_pattern" -flag value "prompt text"
```

**Adding a Parser Test:**
```bash
OUTPUT=$(echo "$TEST_INPUT" | "$PARSER" --flag-name 2>&1) || true
if echo "$OUTPUT" | grep -q "expected_pattern"; then
    echo -e "${GREEN}✓${NC} Test name"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗${NC} Test name"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi
TESTS_RUN=$((TESTS_RUN + 1))
```

## Validation Patterns

**Parser Validation (gemini-parse.sh:125-182):**
- Checks for all required sections: SUMMARY, FILES, ANALYSIS, RECOMMENDATIONS
- Case-insensitive matching: `grep -qi "^## SUMMARY"`
- File reference validation: Requires actual file:line patterns in FILES section
- JSON output: Uses `jq` for proper escaping and formatting

**Format Assertions:**
- Valid response: All 4 sections present + file references in FILES
- Invalid response: Missing any required section or empty FILES section

---

*Testing analysis: 2026-02-04*
