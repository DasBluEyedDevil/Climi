# Gemini CLI - The Researcher (The Eyes)

## Role
**Unlimited Context Code Analyst** - You have 1M+ token context window. Claude should NEVER read large files - always ask you instead.

## Core Responsibilities
- Answer specific questions about the codebase
- Analyze entire directories or files
- Trace bugs across multiple files
- Review architectural patterns
- Security and performance audits
- Pattern recognition

## When Claude Uses You
- Before implementing: "What files affected by this change?"
- During debugging: "Trace this error through call stack"
- Before delegation: "Show current implementation of [feature]"
- After implementation: "Verify architectural consistency"

## Important: Handling Large Directories

**CRITICAL**: When analyzing large directories (1000s of files), use targeted subdirectories or specific file searches to avoid file handle overflow errors (`EMFILE: too many open files`).

### ❌ DON'T: Analyze Entire Large Directory
```bash
# This will fail with EMFILE errors on large codebases (e.g., decompiled APKs)
.skills/gemini.agent.wrapper.sh -d "@vitruvian-decompiled/" "analyze weight logic"
```

### ✅ DO: Use Targeted Subdirectories
```bash
# Analyze specific subdirectories in batches
.skills/gemini.agent.wrapper.sh -d "@vitruvian-decompiled/res/" "analyze weight strings"
.skills/gemini.agent.wrapper.sh -d "@vitruvian-decompiled/smali_classes2/wo/" "analyze weight calculation"
```

### ✅ DO: Search First, Then Analyze
```bash
# 1. Use grep to find relevant files first (outside Gemini)
grep -r "weight" vitruvian-decompiled --include="*.smali" -l | head -20

# 2. Then analyze only those specific files or directories
.skills/gemini.agent.wrapper.sh -d "@vitruvian-decompiled/smali_classes2/specific_dir/" "analyze weight logic"
```

### ✅ DO: Use Resource Directories for Strings/Config
```bash
# Resource directories are usually small and safe to analyze
.skills/gemini.agent.wrapper.sh -d "@vitruvian-decompiled/res/values/" "find weight-related strings"
```

**Rule of Thumb**: If a directory has >500 files, break it into smaller subdirectories or use grep first to narrow the scope.

## Query Patterns

### Pattern 1: Specific Question
```bash
.skills/gemini.agent.wrapper.sh -d "@app/src/ @app/build.gradle.kts" "
Question: How is BLE device discovery implemented?

Required information:
- File paths with line numbers
- Code excerpts showing scanning logic
- Explanation of how it works
- Related files or dependencies"
```

### Pattern 2: Architecture Analysis
```bash
.skills/gemini.agent.wrapper.sh -d "@app/src/" "
Analyze architecture for implementing workout history export feature.

Provide:
1. Current data persistence patterns
2. Files that will be affected
3. Dependencies and risks
4. Recommended approach
5. Examples from existing code"
```

### Pattern 3: Bug Tracing
```bash
.skills/gemini.agent.wrapper.sh -d "@app/src/" "
Bug: Rep counting stops after 10 reps
Error: [error message if any]
Location: WorkoutManager.kt:245

Trace:
1. Root cause through call stack
2. All affected files
3. Similar patterns that might have same issue
4. Recommended fix with minimal changes

Provide file paths, line numbers, code excerpts."
```

### Pattern 4: Implementation Verification
```bash
.skills/gemini.agent.wrapper.sh -d "@app/src/" "
Changes implemented:
- BleConnectionManager.kt: Added auto-reconnection
- BleState.kt: Updated state model
- ConnectionViewModel.kt: Added reconnection UI

Verify:
1. Architectural consistency
2. No regressions introduced
3. Best practices followed (Kotlin/Android)
4. Security implications
5. Performance impact
6. Edge cases handled

Provide specific findings with file:line references."
```

### Pattern 5: Pattern Search
```bash
.skills/gemini.agent.wrapper.sh -d "@app/src/" "
Find all implementations of coroutine error handling.

For each occurrence:
- File path and line number
- Code excerpt
- How it's used
- Any variations or edge cases"
```

## Output Requirements
Always request:
1. **File paths** with line numbers
2. **Code excerpts** showing relevant implementation
3. **Explanations** of how things work
4. **Related files** or dependencies
5. **Recommendations** or insights

## Token Savings Examples

### Example 1: Find BLE Implementation
**❌ Old Way (Claude reads)**:
- Claude reads BleManager.kt (2k tokens)
- Claude reads BleService.kt (3k tokens)
- Claude reads BleRepository.kt (1k tokens)
- Claude analyzes (500 tokens)
- **Total: 6.5k tokens**

**✅ New Way (Gemini reads)**:
- Claude asks Gemini (300 tokens)
- Gemini responds with summary (0 Claude tokens)
- **Total: 300 tokens (95% savings!)**

## Best Practices

### Be Specific
❌ Vague: "How does this app work?"
✅ Specific: "How is BLE connection state managed? Show the state flow with file paths."

### Request Structured Output
❌ Vague: "Review this code"
✅ Structured: "Review for: 1) Kotlin best practices, 2) coroutine safety, 3) memory leaks. Rate severity."

### Include Context
❌ No context: "Where is the bug?"
✅ With context: "Bug: Crash at BleManager.kt:145 when disconnecting. Trace the disconnect flow."

## Android/Kotlin Context
For VitruvianRedux project:
- Kotlin coroutines and Flow
- Jetpack Compose
- MVVM/ViewModel architecture
- BLE (BluetoothGatt)
- Room database patterns
- Material Design 3

## Quick Reference Commands

```bash
# Understand feature
.skills/gemini.agent.wrapper.sh -d "@app/src/" "How is [feature] implemented?"

# Find files
.skills/gemini.agent.wrapper.sh -d "@app/src/" "Which files handle [functionality]?"

# Trace bug
.skills/gemini.agent.wrapper.sh -d "@app/src/" "Error at [location]. Trace root cause."

# Review code
.skills/gemini.agent.wrapper.sh -d "@app/src/" "Review [files] for security and quality."

# Verify changes
.skills/gemini.agent.wrapper.sh -d "@app/src/" "Changes: [summary]. Verify consistency."

# Pattern search
.skills/gemini.agent.wrapper.sh -d "@app/src/" "Find all uses of [pattern]."

# Full audit
.skills/gemini.agent.wrapper.sh --all-files -o json "Security audit. Output JSON."
```

## Remember
Every time Claude is about to read a file, ask "Should Gemini read this instead?" The answer is almost always **YES**.
