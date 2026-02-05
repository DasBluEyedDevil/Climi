# Multi-Agent-Workflow: Kimi Integration for Claude Code

[![Kimi CLI](https://img.shields.io/badge/Kimi%20CLI-%E2%89%A51.7.0-blue)]()
[![Platform](https://img.shields.io/badge/Platform-macOS%20%7C%20Linux%20%7C%20Windows-green)]()
[![License](https://img.shields.io/badge/License-MIT-yellow)]()

## Overview

Integrate **Kimi K2.5** as a general-purpose R&D subagent for Claude Code. Kimi handles large-context code analysis, research, and investigation while Claude focuses on implementation. This division of labor leverages Kimi's massive context window for reading and Claude's precision for writing.

**Key benefits:**
- Delegate any R&D task to Kimi: code review, debugging, security audits, architecture analysis
- 7 specialized agent roles with appropriate tool access (analysis = read-only, action = full access)
- Template-based prompts for common workflows
- Git diff injection for post-change verification

## Quick Start

```bash
# Clone and install
git clone https://github.com/username/multi-agent-workflow.git
cd multi-agent-workflow
./install.sh

# Test it works
./skills/kimi.agent.wrapper.sh -r reviewer "Review this codebase"

# With thinking mode for deeper analysis
./skills/kimi.agent.wrapper.sh -r reviewer --thinking "Explain the architecture"
```

## Installation

### Prerequisites

| Dependency | Required | Installation |
|------------|----------|--------------|
| **Kimi CLI** | Yes (>=1.7.0) | `uv tool install kimi-cli` or `pip install kimi-cli` |
| **Bash** | Yes | macOS/Linux: built-in, Windows: Git Bash |
| **Git** | Optional | For `--diff` feature |
| **Python** | Yes (>=3.12) | Required by Kimi CLI |

### Install Options

```bash
# Interactive install (prompts for target)
./install.sh

# Global install (all projects, ~/.claude/)
./install.sh --global

# Local install (current directory only)
./install.sh --local

# Custom target
./install.sh --target /path/to/target
```

### Windows Users

Use the PowerShell shim for native PowerShell support:

```powershell
# From PowerShell
.\kimi.ps1 -r reviewer "Review this code"

# Or use Git Bash directly
bash skills/kimi.agent.wrapper.sh -r reviewer "Review this code"
```

The PowerShell shim (`kimi.ps1`) automatically finds Git Bash, WSL, or MSYS2 to execute the bash wrapper.

### Upgrading

Run `./install.sh` again. The installer:
- Detects existing installations
- Offers to create timestamped backups
- Updates wrapper scripts, roles, templates
- Preserves your custom configurations

### Uninstalling

```bash
# Preview what will be removed
./uninstall.sh --dry-run

# Remove installation
./uninstall.sh
```

## Usage

### Basic Invocation

```bash
# With a role
./skills/kimi.agent.wrapper.sh -r <role> "prompt"

# With a template
./skills/kimi.agent.wrapper.sh -t <template> "prompt"

# With both
./skills/kimi.agent.wrapper.sh -r reviewer -t feature "Plan new user authentication"

# With git diff context
./skills/kimi.agent.wrapper.sh -t verify --diff "Verify my changes are correct"

# Set working directory
./skills/kimi.agent.wrapper.sh -r reviewer -w /path/to/project "Review this project"
```

### Command Options

```
USAGE:
    ./skills/kimi.agent.wrapper.sh [OPTIONS] "prompt"

WRAPPER OPTIONS:
    -r, --role ROLE      Agent role (maps to .kimi/agents/ROLE.yaml)
    -m, --model MODEL    Kimi model (default: kimi-for-coding)
    -w, --work-dir PATH  Working directory for Kimi
    -t, --template TPL   Template to prepend (maps to .kimi/templates/TPL.md)
    --diff               Include git diff (HEAD vs working tree) in prompt
    --dry-run            Show command without executing
    --verbose            Show wrapper debug output
    -h, --help           Show help and exit

KIMI CLI OPTIONS (pass-through):
    --thinking           Enable thinking mode for deeper reasoning
    --no-thinking        Disable thinking mode
    -y, --yes, --yolo    Auto-approve all actions
    --print              Run in non-interactive print mode
    (and any other kimi CLI flags)

ENVIRONMENT:
    KIMI_PATH            Override kimi binary location
```

## Agent Roles

All agents are defined in `.kimi/agents/` as YAML + Markdown pairs.

### Analysis Roles (Read-Only)

Analysis roles have restricted tool access - they can read files and search but cannot modify anything. Safe for code review and auditing.

| Role | Purpose | Use Case |
|------|---------|----------|
| **reviewer** | Code quality assessment | Code review, bug detection, best practices |
| **auditor** | Architecture evaluation | Tech debt, patterns, system-level issues |
| **security** | Vulnerability assessment | OWASP, secrets scanning, security audit |

### Action Roles (Full Access)

Action roles have full tool access including shell, file writes, and subagent creation. They can investigate and fix issues autonomously.

| Role | Purpose | Use Case |
|------|---------|----------|
| **debugger** | Bug investigation | Trace bugs, find root cause, apply fixes |
| **refactorer** | Code restructuring | Pattern improvements, DRY, maintainability |
| **implementer** | Feature implementation | Build new features, greenfield freedom |
| **simplifier** | Complexity reduction | Dead code removal, consolidation |

### Tool Access Matrix

| Tool | Analysis Roles | Action Roles |
|------|----------------|--------------|
| ReadFile, Glob, Grep | Yes | Yes |
| SearchWeb | Yes | Yes |
| Shell | No | Yes |
| WriteFile | No | Yes |
| StrReplaceFile | No | Yes |
| CreateSubagent | No | Yes |

## Templates

Templates provide pre-built prompt structures for common tasks. Located in `.kimi/templates/`.

| Template | Flag | Use Case |
|----------|------|----------|
| `feature` | `-t feature` | Plan new feature implementation |
| `bug` | `-t bug` | Investigate and analyze bugs |
| `verify` | `-t verify` | Post-change verification (use with `--diff`) |
| `architecture` | `-t architecture` | System architecture review |
| `implement-ready` | `-t implement-ready` | Generate implementation guidance |
| `fix-ready` | `-t fix-ready` | Generate fix instructions |

### Example Template Usage

```bash
# Plan a new feature
./skills/kimi.agent.wrapper.sh -r reviewer -t feature "Add password reset functionality"

# Verify changes after implementation
./skills/kimi.agent.wrapper.sh -t verify --diff "Verify the authentication changes"

# Bug investigation
./skills/kimi.agent.wrapper.sh -r debugger -t bug "NullPointerException in UserService.kt:245"
```

## Claude Code Slash Commands

When installed, these slash commands are available in Claude Code:

| Command | Role | Description |
|---------|------|-------------|
| `/kimi-analyze` | reviewer | Codebase analysis and exploration |
| `/kimi-audit` | auditor | Architecture and quality audit |
| `/kimi-trace` | debugger | Bug tracing with full tool access |
| `/kimi-verify` | (template) | Post-change verification with diff |

### Usage in Claude Code

```
/kimi-analyze src/ How is authentication implemented?
/kimi-audit . What patterns need improvement?
/kimi-trace "Error at auth.ts:145"
/kimi-verify Check my changes are correct
```

## Configuration

### CLAUDE.md Integration

Add the Kimi section to your project's CLAUDE.md (template at `.claude/CLAUDE.md.kimi-section`):

```markdown
## Kimi Context Companion

**Division of labor:** Kimi = Eyes (K2.5 large context), Claude = Hands (implementation)

**Workflow:** Analyze (Kimi) -> Implement (Claude) -> Verify (Kimi)

## Delegation Rules

**Delegate to Kimi when:** >100 lines, multiple files, unfamiliar code, tracing logic

**Handle directly:** Single-file edits, new code, tests/builds, docs

## Roles

`reviewer` `auditor` `debugger` `security` `refactorer` `implementer` `simplifier`
```

### Context File

Create `.kimi/context.md` or `KimiContext.md` in your project root. This content is automatically injected into every Kimi query.

```markdown
# Project Context

- Framework: Next.js 15 with App Router
- Language: TypeScript strict mode
- Database: PostgreSQL with Prisma ORM
- Testing: Jest + Testing Library

## Key Conventions

- Use server actions for mutations
- Prefer React Server Components
- All API routes require authentication
```

### Environment Variables

| Variable | Purpose |
|----------|---------|
| `KIMI_PATH` | Override kimi binary location (useful on Windows) |

## Architecture

```
+---------------------------------------------------------+
|                    Claude Code                           |
|  +-- /kimi-* slash commands                              |
|  +-- SKILL.md (teaches delegation rules)                 |
|  +-- CLAUDE.md.kimi-section (user config)                |
+----------------------------+----------------------------+
                             | invokes
                             v
+---------------------------------------------------------+
|               kimi.agent.wrapper.sh                      |
|  +-- CLI validation (kimi >= 1.7.0)                      |
|  +-- Role resolution (.kimi/agents/*.yaml)               |
|  +-- Template loading (.kimi/templates/*.md)             |
|  +-- Context injection (context.md, --diff)              |
|  +-- Prompt assembly                                     |
+----------------------------+----------------------------+
                             | delegates to
                             v
+---------------------------------------------------------+
|              Kimi CLI (kimi-for-coding)                  |
|  +-- K2.5 large context analysis                         |
|  +-- Agent-based tool access                             |
|  +-- Structured output                                   |
+---------------------------------------------------------+
```

### File Structure

```
multi-agent-workflow/
+-- install.sh                      # Automated installer
+-- uninstall.sh                    # Clean uninstaller
+-- kimi.ps1                        # PowerShell shim (Windows)
|
+-- skills/
|   +-- kimi.agent.wrapper.sh       # Core wrapper script
|   +-- Claude-Code-Integration.md  # Integration guide
|
+-- .kimi/
|   +-- agents/                     # 7 agent roles
|   |   +-- reviewer.yaml + .md
|   |   +-- auditor.yaml + .md
|   |   +-- security.yaml + .md
|   |   +-- debugger.yaml + .md
|   |   +-- refactorer.yaml + .md
|   |   +-- implementer.yaml + .md
|   |   +-- simplifier.yaml + .md
|   +-- templates/                  # 6 query templates
|       +-- feature.md
|       +-- bug.md
|       +-- verify.md
|       +-- architecture.md
|       +-- implement-ready.md
|       +-- fix-ready.md
|
+-- .claude/
    +-- commands/kimi/              # Slash commands
    |   +-- kimi-analyze.md
    |   +-- kimi-audit.md
    |   +-- kimi-trace.md
    |   +-- kimi-verify.md
    +-- skills/kimi-delegation/
    |   +-- SKILL.md                # Claude skill definition
    +-- CLAUDE.md.kimi-section      # Config template
```

## Response Format

All Kimi agents return structured output for consistent parsing:

```markdown
## SUMMARY
[1-2 sentence overview of findings]

## FILES
- path/to/file.ext:LINE - description
- path/to/another.ext:LINE - description

## ANALYSIS
[Detailed findings, code analysis, explanations]

## RECOMMENDATIONS
1. First actionable item
2. Second actionable item
3. Third actionable item
```

## Troubleshooting

### "kimi not found"

```bash
# Install kimi CLI
uv tool install kimi-cli
# or
pip install kimi-cli

# Verify installation
kimi --version

# If PATH issues persist (common on Windows), set KIMI_PATH:
export KIMI_PATH=/path/to/kimi
```

### "role not found"

```bash
# Check .kimi/agents/ directory exists and contains YAML files
ls -la .kimi/agents/

# Available roles are shown in error message
# Verify the YAML file exists: .kimi/agents/<role>.yaml
```

### "template not found"

```bash
# Check .kimi/templates/ directory
ls -la .kimi/templates/

# Available templates are shown in error message
# Verify the file exists: .kimi/templates/<template>.md
```

### Windows Issues

1. **Git Bash not found:** Install Git for Windows, ensure "Git Bash" option is selected
2. **PowerShell shim fails:** Run `.\kimi.ps1 --verbose` to see which bash it's trying to use
3. **Path issues:** Set `KIMI_PATH` environment variable to kimi.exe location

### Version Warnings

```bash
# Warning: kimi CLI x.y.z is below minimum 1.7.0
# Upgrade kimi CLI:
uv tool upgrade kimi-cli
# or
pip install --upgrade kimi-cli
```

## Requirements

| Component | Minimum Version | Notes |
|-----------|-----------------|-------|
| **Kimi CLI** | >= 1.7.0 | `--quiet`, `--agent-file` support |
| **Bash** | Any modern | Git Bash on Windows |
| **Python** | >= 3.12 | Required by Kimi CLI |
| **Git** | Any | Optional, for `--diff` feature |
| **OS** | macOS, Linux, Windows | Windows via WSL/Git Bash |

## License

MIT License - see [LICENSE](LICENSE)

## Contributing

1. Fork the repository
2. Make your changes
3. Test with `./skills/kimi.agent.wrapper.sh --dry-run -r reviewer "test"`
4. Ensure all roles and templates load correctly
5. Submit a pull request

### Adding Custom Roles

Create a new role in `.kimi/agents/`:

```yaml
# .kimi/agents/my-role.yaml
version: 1
agent:
  extend: default
  name: my-role
  system_prompt_path: ./my-role.md
  # exclude_tools: [...] # Add for read-only roles
```

```markdown
# .kimi/agents/my-role.md
# My Custom Role

You are a [description]. Your task is to [objective].

## Process
1. First step
2. Second step

## Output Format
Use SUMMARY/FILES/ANALYSIS/RECOMMENDATIONS structure.

## Constraints
- Constraint 1
- Constraint 2
```

### Adding Custom Templates

Create a new template in `.kimi/templates/`:

```markdown
# .kimi/templates/my-template.md
# My Template

You are helping with [task type].

## Context
- Working directory: ${KIMI_WORK_DIR}
- Current time: ${KIMI_NOW}

## Task
[Instructions for the task]

## Output Format
[Expected output structure]
```
