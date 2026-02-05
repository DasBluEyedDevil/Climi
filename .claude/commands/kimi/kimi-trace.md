# Kimi Trace

Delegate bug tracing and debugging investigation to Kimi K2.5.

## Usage

```
/kimi-trace [description of bug or behavior]
```

## What This Does

1. Invokes Kimi CLI via the wrapper with the debugger role
2. Kimi traces execution paths and investigates the issue
3. Has FULL tool access - can read, write, and execute to investigate
4. Returns detailed analysis with root cause and fix recommendations

## Example Invocations

```bash
# Trace a mysterious bug
bash skills/kimi.agent.wrapper.sh -r debugger "Users are getting logged out randomly after 5 minutes"

# Find root cause of an error
bash skills/kimi.agent.wrapper.sh -r debugger "TypeError: Cannot read property 'id' of undefined in UserService"

# Trace execution path
bash skills/kimi.agent.wrapper.sh -r debugger -w src/ "Why does the order total calculation sometimes return NaN?"

# Investigate with deep reasoning
bash skills/kimi.agent.wrapper.sh -r debugger --thinking "Race condition causing duplicate database entries"

# Trace across multiple components
bash skills/kimi.agent.wrapper.sh -r debugger "Data inconsistency between cache and database for user profiles"
```

## When to Use

- **Mysterious bugs:** Issues with unclear root cause
- **Cross-file tracing:** Bugs spanning multiple components
- **Error propagation:** Understanding how errors flow through the system
- **Race conditions:** Timing-related issues
- **State inconsistencies:** Unexpected data states
- **Performance issues:** Slow operations without obvious cause

## Response Format

Kimi returns structured output with these sections:

- **SUMMARY:** Concise description of findings
- **FILES:** Relevant files with line references
- **ANALYSIS:** Detailed investigation including:
  - Commands executed (audit trail)
  - Execution path traced
  - Root cause identification
- **RECOMMENDATIONS:** Specific fixes with code locations

## Important: Debugger Has Full Access

Unlike analysis roles (reviewer, auditor), the debugger role has **FULL tool access**:
- Can read any files
- Can write/modify files for investigation
- Can execute commands to reproduce issues

This allows deeper investigation but means Kimi may make temporary changes.

## Instructions for Claude

When this command is invoked, execute the kimi wrapper via bash (NOT PowerShell):

```bash
bash skills/kimi.agent.wrapper.sh -r debugger "[bug description]"
```

**Required parameters:**
- `-r debugger` - Uses the debugger agent role (full access for investigation)
- Final quoted argument - Detailed description of the bug or behavior

**Optional parameters:**
- `-w [path]` - Focus investigation on specific directory
- `--thinking` - Enable deeper reasoning for complex bugs
- `--verbose` - Show wrapper debug output

**Important:**
- Always include detailed bug description as the final quoted argument
- The debugger role has FULL tool access (unlike read-only analysis roles)
- Review the "Commands executed" section for audit trail
- Use the file:line references to implement the recommended fixes

