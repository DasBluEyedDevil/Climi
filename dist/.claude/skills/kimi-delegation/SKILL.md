---
name: Kimi Research Subagent
description: Delegates development tasks to Kimi K2.5. Use when implementing features, debugging issues, refactoring code, or running tests. Claude architects, Kimi implements.
dependencies:
  - kimi-cli
---

# Kimi R&D Subagent

You have access to Kimi K2.5 as an autonomous R&D agent. **You are the Architect (brain + eyes). Kimi is the Developer (hands).**

## Division of Labor

| Claude (Architect) | Kimi (Developer) |
|-------------------|------------------|
| Design & plan | Implement features |
| Review & approve | Debug & fix bugs |
| Coordinate work | Refactor code |
| Make decisions | Run tests |
| Set direction | Execute tasks |

## When to Delegate to Kimi

**DELEGATE implementation work:**
- Feature implementation from your specs
- Bug investigation and fixing
- Code refactoring tasks
- Test writing and execution
- Multi-file changes you've designed

**KEEP for yourself:**
- Architecture decisions
- Design reviews
- Approving Kimi's work
- User communication
- Strategic planning

### Model Selection: K2 vs K2.5

The v2.0 delegation system intelligently selects between Kimi K2 and K2.5 based on task characteristics:

**Use K2 for:**
- Refactoring and code restructuring
- Testing and test automation
- Debugging and error fixing
- Backend work (APIs, services, data layer)
- Routine maintenance tasks
- Performance optimization

**Use K2.5 for:**
- UI component creation
- Creative feature implementation
- Design and UX work
- Frontend styling and layout
- Responsive design tasks
- Animation and interaction design

## Quick Reference

```bash
# Routine task → Auto-selects K2
./skills/kimi.agent.wrapper.sh --auto-model -r refactorer "Clean up utils.py"

# Creative task → Auto-selects K2.5
./skills/kimi.agent.wrapper.sh --auto-model -r implementer "Create dashboard component"

# Force specific model
KIMI_FORCE_MODEL=k2.5 ./skills/kimi.agent.wrapper.sh -r implementer "Any task"
```

## Automatic Model Selection

Enable automatic model selection with the `--auto-model` flag. The system analyzes your task and files to choose between K2 and K2.5.

### Decision Tree

```
Start
├── KIMI_FORCE_MODEL set? → Use that model (override)
├── --auto-model flag? → Analyze and select
│   ├── File Extensions
│   │   ├── .tsx, .jsx, .css, .scss, .vue, .svelte, .html → K2.5
│   │   └── .py, .js, .ts, .go, .rs, .java, .rb, .sh → K2
│   ├── Task Type
│   │   ├── refactor, test, debug, optimize → K2
│   │   └── feature, component, design, UI → K2.5
│   └── Code Patterns
│       ├── Component patterns (React/Vue/Angular) → K2.5
│       └── Utility/Service patterns → K2
└── Otherwise → Use default (kimi-for-coding)
```

### Confidence Scoring

The system calculates a confidence score (0-100) for each selection:

| Factor | Weight | Description |
|--------|--------|-------------|
| File agreement | +20 | All files suggest same model |
| Task clarity | +20 | Task type clearly identified |
| Pattern match | +10 | Code patterns match selected model |
| Base score | 50 | Starting confidence |

**Threshold:** Default is 75%. Below this, you'll see a warning with the option to override.

### What Happens When Confidence Is Low

When confidence is below the threshold:

1. The system displays a warning: `[model-selection] Warning: Low confidence (X% < 75%)`
2. Shows the recommended model and estimated cost
3. Suggests using `KIMI_FORCE_MODEL` to override
4. Proceeds with the recommendation (doesn't block)

```bash
# Example low-confidence warning
[model-selection] Selected: k2 (confidence: 65%)
[model-selection] Warning: Low confidence (65% < 75%)
[model-selection] Override with KIMI_FORCE_MODEL=k2 or k2.5
```

## Cost Estimation

Estimate delegation costs before execution using the `--show-cost` flag.

### How Cost Estimation Works

1. **Token Estimation:** Character count ÷ 4 (rough heuristic)
2. **Model Multiplier:** K2.5 costs 1.5x more than K2
3. **Speed Categories:**
   - < 1000 tokens: "fast"
   - 1000-5000 tokens: "moderate"
   - > 5000 tokens: "may take time"

### Using --show-cost

```bash
# Show cost estimate before delegating
./skills/kimi.agent.wrapper.sh --auto-model --show-cost -r refactorer "Refactor auth module"

# Output example:
# [model-selection] Cost estimate: ~2,450 tokens (k2, moderate)
```

### When Costs Are Displayed Automatically

Costs are shown automatically when:
- `--show-cost` flag is used
- Confidence is below threshold (to help you decide)
- Cost exceeds `KIMI_COST_THRESHOLD` (default: 10000)

## Override Mechanisms

You can override automatic model selection in several ways:

### 1. Environment Variable (Recommended)

```bash
# Force K2 for all delegations in this session
export KIMI_FORCE_MODEL=k2
./skills/kimi.agent.wrapper.sh --auto-model -r debugger "Fix the bug"

# Force K2.5 for a single command
KIMI_FORCE_MODEL=k2.5 ./skills/kimi.agent.wrapper.sh --auto-model -r implementer "Create UI"
```

### 2. Command-Line Flag

```bash
# Use --model to explicitly set the model (bypasses auto-selection)
./skills/kimi.agent.wrapper.sh --model kimi-for-coding -r implementer "Task"
```

### 3. Override Precedence

Override mechanisms take precedence in this order:

1. `KIMI_FORCE_MODEL` environment variable (highest)
2. `--model` command-line flag
3. `--auto-model` selection
4. Default model (lowest)

## Context Preservation

Maintain conversation context across related delegations using sessions.

### Using --session-id

```bash
# Start a session
./skills/kimi.agent.wrapper.sh --session-id auth-refactor -r refactorer "Refactor auth.ts"

# Continue the same session (context preserved)
./skills/kimi.agent.wrapper.sh --session-id auth-refactor -r debugger "Fix auth bug"
```

### Environment Variable

```bash
# Set session for all commands in a script
export KIMI_SESSION_ID=feature-branch-123

# All subsequent delegations share context
./skills/kimi.agent.wrapper.sh -r implementer "Create component"
./skills/kimi.agent.wrapper.sh -r tester "Write tests"
```

### When to Use Sessions

- **Related tasks:** Multiple commands working on the same feature
- **Iterative work:** Debug → fix → verify cycles
- **Long-running work:** Tasks that span multiple commands
- **Context-heavy work:** When Kimi needs to remember previous analysis

## How to Invoke

### Basic Usage

```bash
# Implementation tasks (action roles - full tool access)
./skills/kimi.agent.wrapper.sh -r implementer "Build the auth module per spec"
./skills/kimi.agent.wrapper.sh -r debugger "Fix the null pointer in UserService"
./skills/kimi.agent.wrapper.sh -r refactorer "Extract payment logic into service"
./skills/kimi.agent.wrapper.sh -r simplifier "Reduce complexity in data layer"

# Analysis tasks (read-only roles)
./skills/kimi.agent.wrapper.sh -r reviewer "Review the PR changes"
./skills/kimi.agent.wrapper.sh -r security "Audit authentication flow"
./skills/kimi.agent.wrapper.sh -r auditor "Check architecture compliance"
```

### With Auto-Model Selection

```bash
# Let the system choose K2 or K2.5
./skills/kimi.agent.wrapper.sh --auto-model -r refactorer "Clean up utils.py"
./skills/kimi.agent.wrapper.sh --auto-model -r implementer "Create React component"

# With cost preview
./skills/kimi.agent.wrapper.sh --auto-model --show-cost -r debugger "Investigate crash"

# With custom confidence threshold
./skills/kimi.agent.wrapper.sh --auto-model --confidence-threshold 80 -r implementer "Task"
```

### With Context Preservation

```bash
# Use explicit session ID
./skills/kimi.agent.wrapper.sh --session-id my-session -r implementer "Task 1"
./skills/kimi.agent.wrapper.sh --session-id my-session -r debugger "Task 2"

# Include git diff for context
./skills/kimi.agent.wrapper.sh --auto-model --diff -r reviewer "Review changes"
```

## Roles

| Role | Type | Use Case | Typical Model |
|------|------|----------|---------------|
| `implementer` | Action | Build features from specs | K2.5 (UI), K2 (backend) |
| `debugger` | Action | Investigate and fix bugs | K2 |
| `refactorer` | Action | Restructure code | K2 |
| `simplifier` | Action | Reduce complexity | K2 |
| `reviewer` | Analysis | Code review (read-only) | K2 |
| `security` | Analysis | Security audit (read-only) | K2 |
| `auditor` | Analysis | Architecture check (read-only) | K2 |

## Decision Flow

```
┌─────────────────────────────────────────────────────────────┐
│                        Start                                │
└──────────────────────┬──────────────────────────────────────┘
                       │
           ┌───────────▼────────────┐
           │ KIMI_FORCE_MODEL set?  │
           └───────────┬────────────┘
                       │
          ┌────────────┴────────────┐
          │ Yes                     │ No
          ▼                         ▼
┌──────────────────┐    ┌──────────────────────┐
│ Use forced model │    │ --auto-model flag?   │
│ (100% confidence)│    └──────────┬───────────┘
└──────────────────┘               │
                          ┌────────┴────────┐
                          │ Yes             │ No
                          ▼                 ▼
                 ┌─────────────────┐  ┌──────────────────┐
                 │ Analyze task    │  │ Use default model│
                 │ and select K2/  │  │ (kimi-for-coding)│
                 │ K2.5            │  └──────────────────┘
                 └────────┬────────┘
                          │
                 ┌────────▼────────┐
                 │ Calculate       │
                 │ confidence      │
                 └────────┬────────┘
                          │
                 ┌────────▼────────┐
                 │ Confidence >=   │
                 │ threshold?      │
                 └────────┬────────┘
                          │
                 ┌────────┴────────┐
                 │ Yes             │ No
                 ▼                 ▼
        ┌────────────────┐  ┌──────────────────────┐
        │ Proceed with   │  │ Show warning +       │
        │ selected model │  │ cost, then proceed   │
        └────────────────┘  └──────────────────────┘
```

## Examples by Task Type

| Task | Files | Auto-Selected Model | Why |
|------|-------|---------------------|-----|
| Refactor Python utilities | `*.py` | K2 | Backend files + refactoring |
| Create React component | `*.tsx` | K2.5 | UI files + feature work |
| Debug Go backend | `*.go` | K2 | Backend files + debugging |
| Style UI components | `*.css`, `*.scss` | K2.5 | Styling files |
| Write unit tests | `*.test.ts` | K2 | Testing task |
| Implement API endpoint | `*.py`, `*.js` | K2 | Backend + feature (files win) |
| Design dashboard layout | `*.tsx`, `*.css` | K2.5 | UI files dominate |

## Configuration

### File Extension Mapping

Extension mappings are defined in `skills/lib/model-rules.json`:

```json
{
  "extensions": {
    "k2.5": ["tsx", "jsx", "css", "scss", "vue", "svelte", "html"],
    "k2": ["py", "js", "ts", "go", "rs", "java", "rb", "sh", "bash"]
  },
  "patterns": {
    "k2": ["*.test.*", "*.spec.*"],
    "k2.5": ["*component*", "*Component*"]
  }
}
```

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `KIMI_FORCE_MODEL` | (none) | Force model selection (k2 or k2.5) |
| `KIMI_SESSION_ID` | (auto) | Default session ID for context |
| `KIMI_CONFIDENCE_THRESHOLD` | 75 | Minimum confidence before warning |
| `KIMI_COST_THRESHOLD` | 10000 | Cost threshold for auto-prompting |

## Templates

```bash
./skills/kimi.agent.wrapper.sh -t implement-ready "spec"  # Implementation spec
./skills/kimi.agent.wrapper.sh -t fix-ready "bug desc"    # Bug fix spec
./skills/kimi.agent.wrapper.sh -t verify --diff "check"   # Post-change verify
```

## Troubleshooting

### Model Not Auto-Selected

**Problem:** Auto-selection not working, using default model

**Solution:**
- Ensure `--auto-model` flag is included
- Check that `kimi-model-selector.sh` exists in `skills/`
- Verify `skills/lib/model-rules.json` exists

### Wrong Model Selected

**Problem:** System chose K2 when you wanted K2.5 (or vice versa)

**Solution:**
- Use `KIMI_FORCE_MODEL=k2.5` to override
- Check file extensions in your task description
- Add more specific task keywords ("component", "UI", "refactor")

### Cost Too High

**Problem:** Delegation is expensive

**Solution:**
- Use `--show-cost` to preview before delegating
- Break large tasks into smaller chunks
- Use K2 instead of K2.5 for routine work
- Reduce context by specifying fewer files

### Context Lost Between Commands

**Problem:** Kimi doesn't remember previous work

**Solution:**
- Use `--session-id` to maintain context
- Set `KIMI_SESSION_ID` for batch operations
- Ensure session ID is consistent across related commands

## Migration from v1.0

Existing workflows continue to work unchanged. v2.0 features are **opt-in**:

| v1.0 Usage | v2.0 Equivalent | Notes |
|------------|-----------------|-------|
| `./skills/kimi.agent.wrapper.sh -r role "task"` | Same | No change needed |
| `./skills/kimi.agent.wrapper.sh -m model "task"` | Same | Still works |
| (manual model choice) | Add `--auto-model` | Enable auto-selection |
| (no cost preview) | Add `--show-cost` | Enable cost estimation |
| (no session) | Add `--session-id` | Enable context preservation |

### Gradual Adoption Path

1. **Start with existing workflows** - Everything works as before
2. **Add `--auto-model` to new tasks** - Try auto-selection
3. **Use `--show-cost` for large tasks** - Preview expensive operations
4. **Add `--session-id` for multi-step work** - Maintain context
5. **Set `KIMI_FORCE_MODEL` when needed** - Override when auto-selection is wrong

## Workflow Pattern

1. **You Design**: Create spec/plan for the work
2. **Kimi Analyzes**: Auto-selects model based on task (if `--auto-model`)
3. **You Confirm**: Review cost estimate (if `--show-cost`)
4. **Kimi Implements**: Delegates to appropriate role and model
5. **Kimi Reports**: Returns structured output
6. **You Review**: Approve or request changes
7. **Kimi Verifies**: Run verification if needed (with same session)

---

**Version:** 2.0
**Last Updated:** 2026-02-05
**See Also:** `skills/kimi-model-selector.sh`, `skills/kimi-cost-estimator.sh`
