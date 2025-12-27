# Claude Code Integration Guide

This guide shows how to integrate Gemini's large-context analysis into your Claude Code workflow for maximum efficiency.

## Core Philosophy

**Gemini = Eyes** (reads everything, 1M+ context)  
**Claude Code = Hands** (implements based on what Gemini sees)

By separating research (Gemini) from implementation (Claude), you conserve Claude's tokens and maintain faster response times.

## The Three-Step Workflow

### Step 1: Analyze with Gemini

Before implementing any feature or fixing any bug, query Gemini to understand the codebase:

```bash
./skills/gemini.agent.wrapper.sh -d "@src/" "[your specific question]"
```

**What to ask for**:
- File paths with line numbers
- Code excerpts (not entire files)
- Architectural patterns
- Related dependencies
- Potential risks or edge cases

### Step 2: Implement with Claude Code

Using Gemini's analysis:
1. You now know which files to modify
2. You understand existing patterns
3. You have architectural context
4. You can implement efficiently without reading large files

### Step 3: Verify with Gemini

After implementation, verify your changes:

```bash
./skills/gemini.agent.wrapper.sh -d "@src/" "Changes made: [summary]. Verify consistency and check for regressions."
```

## When to Query Gemini

### ✅ Always Query Gemini For:

1. **Understanding unfamiliar code**
   - "How is [feature] implemented?"
   - "Explain the architecture of [system]"
   - "What does [component] do?"

2. **Before making changes**
   - "Which files will be affected by adding [feature]?"
   - "Show me the current implementation of [functionality]"
   - "What dependencies does [component] have?"

3. **Debugging**
   - "Trace this error through the call stack"
   - "Find all places where [function] is called"
   - "Why might [symptom] be occurring?"

4. **After implementation**
   - "Verify that my changes to [files] are consistent with the architecture"
   - "Check if my implementation follows existing patterns"
   - "Are there any regressions from my changes?"

### ❌ Don't Query Gemini For:

1. **Simple tasks Claude can handle**
   - Single-file edits with obvious changes
   - Adding simple helper functions
   - Formatting or style fixes

2. **Implementation work**
   - Gemini analyzes, Claude implements
   - Don't ask Gemini to write code

3. **Writing tests or docs**
   - Claude handles test and documentation writing
   - Gemini can verify tests are comprehensive

## Query Pattern Templates

### Using Roles

The wrapper now supports predefined roles that inject specialized system prompts:

```bash
# Code review with security focus
./skills/gemini.agent.wrapper.sh -d "@src/" -r reviewer "Review the authentication module"

# Architecture planning
./skills/gemini.agent.wrapper.sh -d "@src/" -r planner "Design a caching layer"

# Code explanation for onboarding
./skills/gemini.agent.wrapper.sh -d "@src/" -r explainer "How does the payment flow work?"

# Bug tracing
./skills/gemini.agent.wrapper.sh -d "@src/" -r debugger "Error at auth.ts:145"
```

**Available Roles**:
| Role | Focus |
|------|-------|
| `reviewer` | Code quality, bugs, security, performance |
| `planner` | Architecture, implementation strategies |
| `explainer` | Code explanation, mentoring |
| `debugger` | Error tracing, root cause analysis |
| **Large-Context Roles** (leverage 1M tokens) | |
| `auditor` | Codebase-wide patterns, tech debt, health report |
| `migrator` | Large-scale migration planning |
| `documenter` | Comprehensive documentation generation |
| `security` | Deep security audit across all files |
| `dependency-mapper` | Dependency graph and coupling analysis |
| `onboarder` | New developer onboarding guide |

### Using Templates

Templates provide structured query formats for common tasks:

```bash
# New feature analysis
./skills/gemini.agent.wrapper.sh -d "@src/" -t feature "Add user profile editing"

# Bug investigation
./skills/gemini.agent.wrapper.sh -d "@src/" -t bug "Login fails with 401 on mobile"

# Post-implementation verification
./skills/gemini.agent.wrapper.sh -d "@src/" -t verify "Added password reset in auth/reset.ts"

# Architecture overview
./skills/gemini.agent.wrapper.sh -d "@src/" -t architecture "Authentication system"
```

**Available Templates**:
| Template | Use Case |
|----------|----------|
| `feature` | Pre-implementation analysis |
| `bug` | Bug investigation and tracing |
| `verify` | Post-implementation verification |
| `architecture` | System architecture overview |

### Conversation Mode (--chat)

To maintain context across multiple queries (like a chat session), use the `--chat` flag with a session name:

```bash
# First query starts the session
./skills/gemini.agent.wrapper.sh --chat my-session "Explain the auth logic"

# Second query knows about the first
./skills/gemini.agent.wrapper.sh --chat my-session "Can you simplify that function?"
```

History is stored in `.gemini/history/<session-name>.json`.

### Smart Context (--smart-ctx)

Instead of manually specifying directories, let the wrapper find relevant files using keyword search:

```bash
# Automatically finds files containing "authentication" and adds them to context
./skills/gemini.agent.wrapper.sh --smart-ctx "authentication" "Review the security"
```

This uses `grep` to find the top 20 relevant files, preventing token waste on unrelated files.

### Context Injection with GEMINI.md

Place a `GEMINI.md` file in your project root or `.gemini/` directory to auto-inject context:

```markdown
# Gemini Context File

## Your Role
You are the Lead Architect for this project...

## Project Constraints
- Use TypeScript strict mode
- Follow existing naming conventions
```

This context is prepended to every query, ensuring consistent project knowledge.

### Custom Roles and Templates

Create project-specific roles and templates in the `.gemini/` directory:

```
.gemini/
├── roles/
│   └── kotlin-expert.md    # Custom role definition
└── templates/
    └── security-audit.md   # Custom query template
```

Use custom roles/templates the same as built-in ones:
```bash
./skills/gemini.agent.wrapper.sh -r kotlin-expert "Review this coroutine code"
./skills/gemini.agent.wrapper.sh -t security-audit "Audit the auth module"
```

### Advanced Features

#### Git Diff Injection (`--diff`)

Include staged changes or compare against a branch:

```bash
# Include current staged changes
./skills/gemini.agent.wrapper.sh --diff -d "@src/" "Verify these changes"

# Compare against main branch
./skills/gemini.agent.wrapper.sh --diff main -d "@src/" "Review my feature branch changes"
```


#### Response Caching (`--cache`)

Cache responses for repeated queries (saves API calls):

```bash
# First query hits API and caches
./skills/gemini.agent.wrapper.sh --cache -d "@src/" "How is auth implemented?"

# Repeated query uses cache instantly
./skills/gemini.agent.wrapper.sh --cache -d "@src/" "How is auth implemented?"

# Clear cache when needed
./skills/gemini.agent.wrapper.sh --clear-cache
```

#### Structured Output (`--schema`)

Get machine-readable JSON responses:

```bash
# Get files as JSON array
./skills/gemini.agent.wrapper.sh --schema files -d "@src/" "Which files handle auth?"

# Get issues as JSON array with severity
./skills/gemini.agent.wrapper.sh --schema issues -d "@src/" "Security audit"

# Get implementation plan as structured JSON
./skills/gemini.agent.wrapper.sh --schema plan -d "@src/" "Add user export feature"
```

Available schemas: `files`, `issues`, `plan`, `json`

#### Batch Processing (`--batch`)

Process multiple queries from a file:

```bash
# queries.txt (one query per line, # for comments)
# How is authentication implemented?
# What files handle user data?
# Security audit of the API layer

./skills/gemini.agent.wrapper.sh --batch queries.txt -d "@src/"
```

### Dry Run Mode

Test your prompts without executing:

```bash
./skills/gemini.agent.wrapper.sh --dry-run -d "@src/" -r reviewer -t verify "Test prompt"
```

This shows the fully constructed prompt including context, role, and template.

```bash
./skills/gemini.agent.wrapper.sh -d "@app/src/" "
How is [FEATURE_NAME] currently implemented?

Please provide:
1. Main files involved (with line numbers)
2. Code excerpts showing key logic
3. Data flow from start to finish
4. Related components or dependencies
5. Any existing tests
"
```

### Template 2: Pre-Implementation Analysis

```bash
./skills/gemini.agent.wrapper.sh -d "@app/src/" "
I need to implement [NEW_FEATURE].

Please analyze:
1. Which files will need to be modified?
2. What existing patterns should I follow?
3. What dependencies or services exist?
4. Are there similar features I can reference?
5. What risks or edge cases should I consider?
"
```

### Template 3: Bug Investigation

```bash
./skills/gemini.agent.wrapper.sh -d "@app/src/" "
Bug: [DESCRIPTION]
Location: [FILE:LINE] (if known)
Symptoms: [WHAT_HAPPENS]

Please trace:
1. Root cause analysis
2. Call stack leading to the issue
3. All affected files with line numbers
4. Similar patterns that might have the same bug
5. Recommended fix approach
"
```

### Template 4: Post-Implementation Verification

```bash
./skills/gemini.agent.wrapper.sh -d "@app/src/" "
I implemented [FEATURE] with the following changes:
- [FILE1]: [CHANGES]
- [FILE2]: [CHANGES]
- [FILE3]: [CHANGES]

Please verify:
1. Architectural consistency
2. Existing patterns are followed
3. No obvious regressions
4. Edge cases are handled
5. Security implications (if applicable)
6. Performance considerations

Provide specific file:line references for any issues.
"
```

### Template 5: Architecture Overview

```bash
./skills/gemini.agent.wrapper.sh -d "@app/src/" "
Explain the architecture of [SYSTEM_NAME].

Provide:
1. High-level component organization
2. Key files and their responsibilities
3. Data flow diagrams (in text/mermaid)
4. Inter-component communication patterns
5. Important design decisions or patterns
"
```

## Integration Strategies

### Strategy 1: Gemini-First Development

For every task:
1. Query Gemini to understand context
2. Implement based on Gemini's findings
3. Verify with Gemini before committing

**Benefit**: Maximum token efficiency, lowest risk of breaking existing patterns.

### Strategy 2: Iterative Research

For complex features:
1. High-level overview (Gemini)
2. Implement phase 1 (Claude)
3. Deep dive on next component (Gemini)
4. Implement phase 2 (Claude)
5. Final verification (Gemini)

**Benefit**: Manageable chunks, reduced cognitive load.

### Strategy 3: Bug Triage Workflow

For debugging:
1. Symptoms → Gemini analysis
2. Gemini identifies likely causes
3. Claude implements fix
4. Gemini verifies fix doesn't cause regressions

**Benefit**: Rapid bug tracing across multiple files.

## Advanced Techniques

### Targeted Analysis for Large Codebases

For very large projects, narrow the scope:

```bash
# Instead of entire project
./skills/gemini.agent.wrapper.sh -d "@large-project/" "..."

# Use grep first to find relevant areas
grep -r "authentication" src/ -l | head -20

# Then analyze only relevant subdirectories
./skills/gemini.agent.wrapper.sh -d "@src/auth/ @src/services/auth/" "How is authentication implemented?"
```

### Batch Queries for Related Analysis

If you need multiple related analyses, batch them:

```bash
./skills/gemini.agent.wrapper.sh -d "@app/" "
Multi-part analysis for implementing user profiles:

1. How is user data currently stored? (database schema)
2. What UI patterns exist for displaying user info?
3. How is authentication tied to user identity?
4. Where would I add a profile editing feature?

Provide file paths and code excerpts for each.
"
```

### JSON Output for Structured Data

For programmatic consumption:

```bash
./skills/gemini.agent.wrapper.sh -d "@app/" -o json "
Find all API endpoints in the codebase.

Return JSON: [{\"path\": \"...\", \"file\": \"...\", \"line\": N, \"method\": \"...\"}]
"
```

## Token Optimization Tips

### Use Gemini for Reading, Claude for Writing

- **Don't**: Have Claude read 10 files to understand architecture (~10k tokens)
- **Do**: Have Gemini summarize architecture (~300 Claude tokens)

### Request Concise Summaries

Guide Gemini to provide focused analysis:
- "Provide file paths and line numbers"
- "Show only key code excerpts, not entire files"
- "Summarize in bullet points"

### Avoid Redundant Queries

After Gemini analyzes once, use that analysis:
- Save Gemini's response as context for Claude
- Reference it during implementation
- Only query again for verification or new areas

## Common Pitfalls

### ❌ Pitfall 1: Asking Gemini to Implement

**Wrong**:
```bash
./skills/gemini.agent.wrapper.sh "Implement login feature in React"
```

**Right**:
```bash
./skills/gemini.agent.wrapper.sh -d "@app/src/" "How is authentication currently handled? Show me the patterns I should follow for implementing login."
```

### ❌ Pitfall 2: Vague Queries

**Wrong**:
```bash
./skills/gemini.agent.wrapper.sh -d "@app/" "How does this app work?"
```

**Right**:
```bash
./skills/gemini.agent.wrapper.sh -d "@app/src/" "How does user authentication flow from login UI to API to database? Show the complete path with file:line references."
```

### ❌ Pitfall 3: Skipping Verification

**Wrong**:
- Query Gemini
- Implement
- Commit

**Right**:
- Query Gemini
- Implement
- Verify with Gemini
- Commit

## Example Workflow: Adding a New Feature

Let's walk through adding a "forgot password" feature:

### Step 1: Query Gemini for Context

```bash
./skills/gemini.agent.wrapper.sh -d "@app/src/" "
How is user authentication currently implemented?

Show me:
1. Login flow (UI → API → Database)
2. Password storage and validation
3. Existing email sending patterns
4. Where to add password reset functionality
"
```

**Gemini responds**: [detailed analysis with file paths]

### Step 2: Implement in Claude Code

Using Gemini's analysis, Claude implements:
- Password reset API endpoint
- Email service integration
- Reset token generation and validation
- UI for forgot password flow

### Step 3: Verify with Gemini

```bash
./skills/gemini.agent.wrapper.sh -d "@app/src/" "
Changes made for forgot password feature:
- auth/reset-password.ts: New API endpoint
- services/email.ts: Added password reset email template
- components/ForgotPassword.tsx: New UI component

Verify:
1. Follows existing auth patterns
2. Email service integration matches existing patterns
3. No security issues
4. Token expiration handled correctly
"
```

**Gemini responds**: [verification with any issues found]

### Step 4: Fix Issues (if any)

If Gemini found issues, Claude fixes them and repeats Step 3.

### Step 5: Commit

Once Gemini verifies everything is consistent, commit the changes.

## Best Practices Summary

1. **Always query Gemini before reading large files**
2. **Be specific** - request file paths, line numbers, code excerpts
3. **Use templates** - consistent query patterns get better results
4. **Verify after implementing** - let Gemini catch regressions
5. **Narrow the scope** - target specific directories for large projects
6. **Batch related queries** - reduce round trips
7. **Save Gemini's analysis** - reference it during implementation

## Troubleshooting

### Gemini's Response is Too Long

Make your query more specific:
- Request "key excerpts only, not entire files"
- Target specific subdirectories instead of entire project
- Ask for bullet-point summaries

### Gemini Missed Relevant Files

Expand the search scope:
```bash
# Add more directories
./skills/gemini.agent.wrapper.sh -d "@src/ @lib/ @utils/" "..."

# Or use --all-files for comprehensive search
./skills/gemini.agent.wrapper.sh --all-files "..."
```

### Analysis Doesn't Match Codebase

Ensure you're analyzing the right directory:
- Verify the `@directory/` paths are correct
- Check that files aren't in `.gitignore` (which Gemini might skip)
- Use absolute paths if needed

## Conclusion

By integrating Gemini as your large-context research companion, you transform Claude Code into an efficient implementation machine while keeping token usage minimal. Remember:

**Gemini reads → Claude implements → Gemini verifies**

This three-step workflow is the key to maximizing productivity while minimizing costs.
