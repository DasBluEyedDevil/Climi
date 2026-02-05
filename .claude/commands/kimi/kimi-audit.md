# Kimi Audit

Delegate code quality and architecture audits to Kimi K2.5.

## Usage

```
/kimi-audit [directory] [focus area]
```

## What This Does

1. Invokes Kimi CLI via the wrapper with the auditor role
2. Kimi performs systematic code quality analysis
3. Returns structured audit report with findings and severity
4. Claude addresses identified issues based on recommendations

## Example Invocations

```bash
# General code quality audit
bash skills/kimi.agent.wrapper.sh -r auditor -w src/ "Audit code quality and best practices"

# Architecture conformance check
bash skills/kimi.agent.wrapper.sh -r auditor -w . "Check if code follows clean architecture principles"

# Specific focus area
bash skills/kimi.agent.wrapper.sh -r auditor -w src/api/ "Audit error handling patterns"

# Performance audit with deep analysis
bash skills/kimi.agent.wrapper.sh -r auditor --thinking -w . "Identify performance bottlenecks"

# Security-focused audit (combines with security role)
bash skills/kimi.agent.wrapper.sh -r security -w src/ "Audit for security vulnerabilities"
```

## When to Use

- **Code quality checks:** Before merging or after large changes
- **Architecture review:** Ensuring code follows established patterns
- **Compliance audits:** Checking adherence to standards
- **Technical debt assessment:** Finding areas needing refactoring
- **Pre-release review:** Final quality gate before deployment

## Response Format

Kimi returns structured output with these sections:

- **SUMMARY:** Overall assessment and audit scope
- **FILES:** List of files audited with issue counts
- **ANALYSIS:** Detailed findings organized by category
- **RECOMMENDATIONS:** Prioritized actions to address issues

## Audit Categories

The auditor role evaluates:
- Code organization and structure
- Error handling patterns
- Naming conventions
- Documentation completeness
- Dependency management
- Test coverage indicators
- Performance considerations
- Security best practices

## Instructions for Claude

When this command is invoked, execute the kimi wrapper via bash (NOT PowerShell):

```bash
bash skills/kimi.agent.wrapper.sh -r auditor -w [directory] "[focus area]"
```

**Required parameters:**
- `-r auditor` - Uses the auditor agent role (analysis-focused, read-only)
- Final quoted argument - The audit focus or scope description

**Optional parameters:**
- `-w [path]` - Set working directory for audit scope
- `--thinking` - Enable deeper analysis for complex audits
- `--verbose` - Show wrapper debug output

**Important:**
- Always include the user's audit focus as the final quoted argument
- The auditor role is read-only (no file modifications)
- For security-specific audits, use `-r security` instead
- Prioritize recommendations by severity when addressing findings

