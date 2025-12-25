# AI Quadrumvirate Orchestration System

**Skill:** quadrumvirate-orchestration
**Category:** Workflow
**When to use:** When implementing features, analyzing code, or performing any non-trivial task

## The Four Roles

| Role | Agent | Specialization | Token Cost |
|------|-------|----------------|------------|
| **Orchestrator** | Claude | Requirements, planning, specs, coordination | Your tokens |
| **Researcher** | Gemini CLI | Code analysis, unlimited context (1M+ tokens) | Free |
| **Engineer #1** | Codex CLI | UI/Compose, visual work, complex reasoning | Free |
| **Engineer #2** | Copilot CLI | Backend, BLE, services, GitHub operations | Free |

---

## Your Role: The Orchestrator

You coordinate all work but perform **minimal direct implementation** to conserve tokens. Your value is in orchestration and decision-making, not in reading files or writing code.

### Token Conservation Rules

#### NEVER Do These (Costs Your Tokens)
- Read files >100 lines (ask Gemini instead)
- Implement complex features directly (delegate to Codex/Copilot)
- Review code yourself (ask Gemini specific questions)
- Analyze directories (use Gemini's 1M context)
- Use Glob/Grep for exploration (use Gemini)

#### ALWAYS Do These (Saves Your Tokens)
- Use Superpowers skills for structured workflows
- Delegate implementation to Codex/Copilot subagents
- Delegate documentation creation to Gemini
- Ask Gemini before reading any code
- Use TodoWrite for task tracking
- ONLY perform trivial edits (<5 lines)

---

## Workflow Pattern

### Phase 1: Requirements & Planning (~1k Your Tokens)
```
1. Gather requirements from user
2. Use superpowers:brainstorming if complex
3. Create TodoWrite plan
4. Log architectural decisions to DevilMCP
```

### Phase 2: Architecture Analysis (0 Your Tokens)
Delegate to Gemini:
```bash
.skills/gemini.agent.wrapper.sh -d "@app/src/ @gradle/" "
Feature request: [description]

Questions:
1. What files will be affected?
2. Similar patterns already implemented?
3. Potential risks?
4. Recommended approach?
5. Dependencies or breaking changes?

Provide file paths and code excerpts."
```

### Phase 3: Implementation Delegation (~1k Your Tokens)
```
1. Create detailed spec from Gemini's analysis
2. Delegate to appropriate engineer:
   - Codex: UI/Compose, visual work, complex algorithms
   - Copilot: Backend/services, BLE, database, GitHub
3. Track progress with TodoWrite
```

### Phase 4: Cross-Checking (0 Your Tokens)
```
1. Engineer A implements
2. Engineer B reviews
3. Both report back
```

### Phase 5: Verification (~1k Your Tokens)
```bash
.skills/gemini.agent.wrapper.sh -d "@app/src/" "
Changes made: [summaries from engineers]

Verify:
1. Architectural consistency
2. No regressions
3. Security implications
4. Performance impact"

# Then: superpowers:verification-before-completion
```

**Total Your Tokens: ~3k** (vs 35k doing it yourself - **91% savings!**)

---

## Agent Selection Guide

### Use Gemini (Researcher) When:
- Analyzing existing code implementation
- Understanding architecture patterns
- Tracing bugs across multiple files
- Security/performance audits
- Pattern recognition
- Verifying changes after implementation

**Wrapper:** `.skills/gemini.agent.wrapper.sh`

### Use Codex (Engineer #1) When:
- Building UI components (Jetpack Compose)
- Implementing complex algorithms
- Visual/design work
- Tasks requiring complex reasoning
- Cross-checking Copilot's backend work

**Wrapper:** `.skills/codex.agent.wrapper.sh`

### Use Copilot (Engineer #2) When:
- Backend service implementation
- BLE operations and connection management
- Database operations (Room)
- GitHub operations (PRs, issues)
- Git operations
- Cross-checking Codex's UI work

**Wrapper:** `.skills/copilot.agent.wrapper.sh`

---

## Delegation Templates

### To Gemini: Code Analysis
```bash
.skills/gemini.agent.wrapper.sh -d "@app/src/" "
Question: How is BLE device discovery implemented?

Required information:
- File paths with line numbers
- Code excerpts showing scanning logic
- Explanation of how it works
- Related files or dependencies"
```

### To Gemini: Architecture Analysis
```bash
.skills/gemini.agent.wrapper.sh -d "@app/src/" "
Analyze architecture for implementing [feature].

Provide:
1. Current patterns in use
2. Files that will be affected
3. Dependencies and risks
4. Recommended approach
5. Examples from existing code"
```

### To Gemini: Bug Tracing
```bash
.skills/gemini.agent.wrapper.sh -d "@app/src/" "
Bug: [description]
Error: [error message if any]
Location: [file:line]

Trace:
1. Root cause through call stack
2. All affected files
3. Similar patterns that might have same issue
4. Recommended fix with minimal changes

Provide file paths, line numbers, code excerpts."
```

### To Gemini: Implementation Verification
```bash
.skills/gemini.agent.wrapper.sh -d "@app/src/" "
Changes implemented:
- [file1]: [change description]
- [file2]: [change description]

Verify:
1. Architectural consistency
2. No regressions introduced
3. Best practices followed
4. Security implications
5. Performance impact
6. Edge cases handled

Provide specific findings with file:line references."
```

### To Codex: UI Implementation
```bash
.skills/codex.agent.wrapper.sh "IMPLEMENTATION TASK:

**Objective**: [Clear, one-line goal]

**Requirements**:
- [Detailed requirement 1]
- [Detailed requirement 2]

**Context from Gemini**:
[Paste Gemini's analysis]

**Files to Modify**:
- [file path]: [specific changes]

**TDD Required**: Yes

**After Completion**:
1. Run tests: ./gradlew test
2. Take screenshots if UI
3. Report changes and test results"
```

### To Copilot: Backend Implementation
```bash
.skills/copilot.agent.wrapper.sh --allow-write "IMPLEMENTATION TASK:

**Objective**: [Clear, one-line goal]

**Requirements**:
- [Detailed requirement 1]
- [Detailed requirement 2]

**Context from Gemini**:
[Paste Gemini's analysis]

**Files to Modify**:
- [file path]: [specific changes]

**TDD Required**: Yes

**After Completion**:
1. Run unit tests: ./gradlew test
2. Report changes and test results"
```

### To Copilot: GitHub Operations
```bash
.skills/copilot.agent.wrapper.sh --allow-github "GITHUB TASK:

**Objective**: Create PR for [feature]

**Requirements**:
- Title: '[type]: [description]'
- Link closes issue #[number]
- Add labels: [labels]

**After Creation**:
Report PR number and URL"
```

---

## Cross-Checking Protocol

After one engineer implements, have the other review:

### Codex Reviews Copilot's Backend
```bash
.skills/codex.agent.wrapper.sh "CODE REVIEW:

**Feature**: [name]
**Files to Review**: [list from Copilot's report]

Review for:
1. Kotlin best practices
2. Coroutine safety
3. Error handling
4. Memory management
5. BLE lifecycle compliance

Provide verdict: APPROVED / NEEDS CHANGES"
```

### Copilot Reviews Codex's UI
```bash
.skills/copilot.agent.wrapper.sh "CODE REVIEW:

**Feature**: [name]
**Files to Review**: [list from Codex's report]

Review for:
1. Compose best practices
2. State management correctness
3. Accessibility
4. Performance (recomposition)
5. Material Design 3 compliance

Provide verdict: APPROVED / NEEDS CHANGES"
```

---

## Documentation Delegation

Delegate documentation to Gemini, not yourself:

```bash
.skills/gemini.agent.wrapper.sh -d "@app/src/" "
Create documentation for [feature/component].

Include:
1. Overview and purpose
2. Architecture diagram (mermaid)
3. API reference
4. Usage examples
5. Edge cases and limitations

Output as markdown."
```

Then review and write the file with Write tool.

---

## Success Metrics

You're doing it right when:
- Token usage is <5k per task
- Gemini is queried before implementation
- Codex/Copilot do all implementation
- Engineers cross-check each other's work
- Superpowers skills used for structure
- TodoWrite tracks progress
- DevilMCP logs all decisions and changes

---

## Quick Reference

```bash
# Gemini: Analyze code
.skills/gemini.agent.wrapper.sh -d "@app/src/" "[question]"

# Codex: UI/Visual work
.skills/codex.agent.wrapper.sh "[task spec]"

# Copilot: Backend/BLE/GitHub
.skills/copilot.agent.wrapper.sh --allow-write "[task spec]"
.skills/copilot.agent.wrapper.sh --allow-github "[github task]"
.skills/copilot.agent.wrapper.sh --allow-git "[git task]"
```

---

## Remember

Your value is in **orchestration and decision-making**, not in reading files or writing code. Every time you're about to read a file or write code, ask yourself: "Should I delegate this instead?" The answer is almost always **YES**.
