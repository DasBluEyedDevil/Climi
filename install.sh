#!/usr/bin/env bash

# Climi Installer
# Installs Kimi CLI integration for Claude Code

set -euo pipefail

# -- Constants ---------------------------------------------------------------
SCRIPT_VERSION="2.0.0"
MIN_KIMI_VERSION="1.7.0"
MIN_BASH_VERSION="4.0"
DEFAULT_TARGET="$HOME/.claude"
DRY_RUN=false
WITH_HOOKS=false

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Get the directory where this script lives
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# -- Command-line argument parsing -------------------------------------------
TARGET_DIR="$DEFAULT_TARGET"
INSTALL_MODE="global"
FORCE_MODE=false
SHOW_HELP=false
DRY_RUN=false
WITH_HOOKS=false

usage() {
    cat <<'USAGE_EOF'
Climi Installer v2.0.0

Usage: install.sh [OPTIONS]

Options:
  -g, --global        Install to ~/.claude/ (default)
  -l, --local         Install to current directory .claude/
  -t, --target PATH   Install to custom directory
  -f, --force         Overwrite without backup prompt
      --dry-run       Show what would be installed without making changes
      --with-hooks    Auto-install git hooks without prompting
  -h, --help          Show this help

v2.0 Features:
  • MCP Server - Expose Kimi as callable MCP tools
  • Git Hooks - Auto-delegate coding tasks via git hooks
  • Model Selection - Automatic K2 vs K2.5 selection

Examples:
  install.sh                    # Interactive mode (default)
  install.sh --global           # Install to ~/.claude/
  install.sh --local            # Install to ./.claude/
  install.sh --target ~/custom  # Install to ~/custom/
  install.sh --global --force   # Global install, skip backup prompt
  install.sh --dry-run          # Preview installation
  install.sh --with-hooks       # Auto-install hooks
USAGE_EOF
    exit 0
}

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -g|--global)
            TARGET_DIR="$HOME/.claude"
            INSTALL_MODE="global"
            shift ;;
        -l|--local)
            TARGET_DIR="$(pwd)/.claude"
            INSTALL_MODE="local"
            shift ;;
        -t|--target)
            [[ -z "${2:-}" ]] && { echo "Error: --target requires a path argument" >&2; exit 1; }
            TARGET_DIR="${2/#\~/$HOME}"
            INSTALL_MODE="custom"
            shift 2 ;;
        -f|--force)
            FORCE_MODE=true
            shift ;;
        --dry-run)
            DRY_RUN=true
            shift ;;
        --with-hooks)
            WITH_HOOKS=true
            shift ;;
        -h|--help)
            usage ;;
        *)
            echo "Unknown option: $1" >&2
            echo "Use --help for usage information" >&2
            exit 1 ;;
    esac
done

# -- Utility functions -------------------------------------------------------

# Detect OS: returns "macos", "linux", "windows", or "unknown"
detect_os() {
    case "$(uname -s)" in
        Darwin*)            echo "macos" ;;
        Linux*)             echo "linux" ;;
        MINGW*|MSYS*|CYGWIN*) echo "windows" ;;
        *)                  echo "unknown" ;;
    esac
}

# Compare two semver strings: returns 0 if $1 >= $2
version_gte() {
    local v1="$1" v2="$2"
    if [[ "$v1" == "$v2" ]]; then return 0; fi
    local highest
    highest=$(printf '%s\n%s' "$v1" "$v2" | sort -V | tail -1)
    [[ "$highest" == "$v1" ]]
}

# Platform-specific install instructions for kimi CLI
show_kimi_install_instructions() {
    local os
    os=$(detect_os)
    echo "" >&2
    echo -e "${YELLOW}Install kimi-cli:${NC}" >&2
    case "$os" in
        macos)
            echo "  brew install kimi-cli" >&2
            echo "  # or: uv tool install kimi-cli" >&2
            ;;
        linux)
            echo "  uv tool install kimi-cli" >&2
            echo "  # or: pip install kimi-cli" >&2
            ;;
        windows)
            echo "  uv tool install kimi-cli" >&2
            echo "  # or: pip install kimi-cli" >&2
            echo "" >&2
            echo "  Tip: Set KIMI_PATH env var if PATH is unreliable after updates" >&2
            ;;
        *)
            echo "  uv tool install kimi-cli" >&2
            echo "  # or: pip install kimi-cli" >&2
            ;;
    esac
    echo "" >&2
    echo "  Requires Python >= 3.12 (3.13 recommended)" >&2
}

# Find kimi binary: KIMI_PATH env var first, then PATH lookup
find_kimi() {
    local kimi_bin=""
    # Check KIMI_PATH env var first (addresses Windows PATH loss)
    if [[ -n "${KIMI_PATH:-}" ]]; then
        if [[ -x "$KIMI_PATH" ]]; then
            echo "$KIMI_PATH"
            return 0
        fi
    fi
    # Fall back to PATH lookup
    kimi_bin=$(command -v kimi 2>/dev/null || true)
    if [[ -n "$kimi_bin" ]]; then
        echo "$kimi_bin"
        return 0
    fi
    return 1
}

# Check kimi version and warn if below minimum
check_kimi_version() {
    local kimi_bin="$1"
    local version_output="" kimi_version=""
    version_output=$("$kimi_bin" --version 2>/dev/null || true)
    kimi_version=$(echo "$version_output" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || true)
    if [[ -z "$kimi_version" ]]; then
        echo -e "  ${YELLOW}⚠${NC} Could not determine kimi CLI version"
        return 0
    fi
    if ! version_gte "$kimi_version" "$MIN_KIMI_VERSION"; then
        echo -e "  ${YELLOW}⚠${NC} kimi CLI $kimi_version is below minimum $MIN_KIMI_VERSION -- some features may not work"
    else
        echo -e "  ${GREEN}✓${NC} kimi CLI $kimi_version"
    fi
    return 0
}

# Logging functions
log_info() {
    echo -e "${BLUE}$1${NC}"
}

log_success() {
    echo -e "${GREEN}$1${NC}"
}

log_warn() {
    echo -e "${YELLOW}$1${NC}"
}

log_error() {
    echo -e "${RED}$1${NC}"
}

# -- v2.0 Component Functions ------------------------------------------------

# Check jq dependency - required for MCP server
check_jq() {
    log_info "Checking jq dependency..."
    
    if command -v jq &> /dev/null; then
        log_success "  ✓ jq $(jq --version) found"
        return 0
    fi
    
    log_error "  ✗ jq not found (required for MCP server)"
    echo ""
    log_warn "jq is required for v2.0 MCP functionality. Install instructions:"
    echo ""
    
    local os
    os=$(detect_os)
    case "$os" in
        macos)
            echo "  macOS:"
            echo "    brew install jq"
            ;;
        linux)
            echo "  Ubuntu/Debian:"
            echo "    sudo apt-get install jq"
            echo ""
            echo "  RHEL/CentOS/Fedora:"
            echo "    sudo yum install jq"
            echo "    # or: sudo dnf install jq"
            ;;
        windows)
            echo "  Windows (Git Bash):"
            echo "    choco install jq"
            echo "    # or download from: https://stedolan.github.io/jq/download/"
            ;;
        *)
            echo "  See: https://stedolan.github.io/jq/download/"
            ;;
    esac
    
    echo ""
    return 1
}

# Check bash version
check_bash_version() {
    log_info "Checking bash version..."
    local bash_version="${BASH_VERSION%%.*}"
    if [[ "${BASH_VERSINFO[0]}" -lt 4 ]]; then
        log_error "  ✗ Bash ${BASH_VERSION} is below minimum $MIN_BASH_VERSION"
        return 1
    fi
    log_success "  ✓ Bash ${BASH_VERSION}"
    return 0
}

# Backup existing config file
backup_config() {
    local config_file="$1"
    if [[ -f "$config_file" ]]; then
        local backup_file="${config_file}.backup.$(date +%Y%m%d%H%M%S)"
        if [[ "$DRY_RUN" == "false" ]]; then
            cp "$config_file" "$backup_file"
            log_warn "  Backed up: $backup_file"
        else
            echo "  [DRY-RUN] Would backup: $config_file → $backup_file"
        fi
    fi
}

# Install MCP server and related tools
install_mcp_server() {
    log_info "Installing MCP server..."
    
    # Create directories
    if [[ "$DRY_RUN" == "false" ]]; then
        mkdir -p "$HOME/.local/bin"
        mkdir -p "$HOME/.config/kimi-mcp"
    else
        echo "  [DRY-RUN] Would create: ~/.local/bin and ~/.config/kimi-mcp"
    fi
    
    # Copy MCP server binary
    if [[ -f "$SCRIPT_DIR/mcp-bridge/bin/kimi-mcp-server" ]]; then
        if [[ "$DRY_RUN" == "false" ]]; then
            cp "$SCRIPT_DIR/mcp-bridge/bin/kimi-mcp-server" "$HOME/.local/bin/"
            chmod +x "$HOME/.local/bin/kimi-mcp-server"
            log_success "  ✓ Installed: kimi-mcp-server"
        else
            echo "  [DRY-RUN] Would install: kimi-mcp-server → ~/.local/bin/"
        fi
    else
        log_warn "  ⚠ MCP server binary not found at $SCRIPT_DIR/mcp-bridge/bin/kimi-mcp-server"
    fi
    
    # Copy kimi-mcp CLI wrapper
    if [[ -f "$SCRIPT_DIR/bin/kimi-mcp" ]]; then
        if [[ "$DRY_RUN" == "false" ]]; then
            cp "$SCRIPT_DIR/bin/kimi-mcp" "$HOME/.local/bin/"
            chmod +x "$HOME/.local/bin/kimi-mcp"
            log_success "  ✓ Installed: kimi-mcp CLI"
        else
            echo "  [DRY-RUN] Would install: kimi-mcp → ~/.local/bin/"
        fi
    fi
    
    # Copy kimi-mcp-setup helper
    if [[ -f "$SCRIPT_DIR/bin/kimi-mcp-setup" ]]; then
        if [[ "$DRY_RUN" == "false" ]]; then
            cp "$SCRIPT_DIR/bin/kimi-mcp-setup" "$HOME/.local/bin/"
            chmod +x "$HOME/.local/bin/kimi-mcp-setup"
            log_success "  ✓ Installed: kimi-mcp-setup helper"
        else
            echo "  [DRY-RUN] Would install: kimi-mcp-setup → ~/.local/bin/"
        fi
    fi
    
    # Create default config if not exists
    local config_file="$HOME/.config/kimi-mcp/config.json"
    if [[ ! -f "$config_file" ]]; then
        if [[ "$DRY_RUN" == "false" ]]; then
            mkdir -p "$HOME/.config/kimi-mcp"
            cat > "$config_file" <<'CONFIG_EOF'
{
  "model": "k2",
  "timeout": 300,
  "roles": {
    "analyze": "reviewer",
    "implement": "implementer",
    "refactor": "refactorer",
    "verify": "reviewer"
  }
}
CONFIG_EOF
            log_success "  ✓ Created default config: ~/.config/kimi-mcp/config.json"
        else
            echo "  [DRY-RUN] Would create: ~/.config/kimi-mcp/config.json"
        fi
    else
        log_warn "  ⚠ Existing config preserved: ~/.config/kimi-mcp/config.json"
    fi
}

# Install model selection tools
install_model_tools() {
    log_info "Installing model selection tools..."
    
    # Create directories
    if [[ "$DRY_RUN" == "false" ]]; then
        mkdir -p "$HOME/.local/bin"
        mkdir -p "$HOME/.config/kimi"
    else
        echo "  [DRY-RUN] Would create: ~/.local/bin and ~/.config/kimi"
    fi
    
    # Copy model selector if exists
    if [[ -f "$SCRIPT_DIR/bin/kimi-model-selector" ]]; then
        if [[ "$DRY_RUN" == "false" ]]; then
            cp "$SCRIPT_DIR/bin/kimi-model-selector" "$HOME/.local/bin/"
            chmod +x "$HOME/.local/bin/kimi-model-selector"
            log_success "  ✓ Installed: kimi-model-selector"
        else
            echo "  [DRY-RUN] Would install: kimi-model-selector → ~/.local/bin/"
        fi
    fi
    
    # Copy cost estimator if exists
    if [[ -f "$SCRIPT_DIR/bin/kimi-cost-estimator" ]]; then
        if [[ "$DRY_RUN" == "false" ]]; then
            cp "$SCRIPT_DIR/bin/kimi-cost-estimator" "$HOME/.local/bin/"
            chmod +x "$HOME/.local/bin/kimi-cost-estimator"
            log_success "  ✓ Installed: kimi-cost-estimator"
        else
            echo "  [DRY-RUN] Would install: kimi-cost-estimator → ~/.local/bin/"
        fi
    fi
    
    # Create default model rules if not exists
    local rules_file="$HOME/.config/kimi/model-rules.json"
    if [[ ! -f "$rules_file" ]]; then
        if [[ "$DRY_RUN" == "false" ]]; then
            mkdir -p "$HOME/.config/kimi"
            cat > "$rules_file" <<'RULES_EOF'
{
  "version": "1.0",
  "models": {
    "k2": {
      "description": "Fast, efficient model for routine tasks",
      "cost_multiplier": 1.0,
      "confidence_threshold": 0.75
    },
    "k2.5": {
      "description": "Stronger model for creative/UI tasks",
      "cost_multiplier": 1.5,
      "confidence_threshold": 0.75
    }
  },
  "file_rules": {
    "backend": [".py", ".js", ".go", ".rs", ".java", ".rb", ".php"],
    "frontend": [".tsx", ".jsx", ".css", ".scss", ".vue", ".svelte"],
    "test": [".test.", ".spec."],
    "component": ["component", "Component"]
  },
  "task_rules": {
    "routine": ["refactor", "test", "fix", "lint", "format"],
    "creative": ["feature", "ui", "design", "implement"]
  }
}
RULES_EOF
            log_success "  ✓ Created default model rules: ~/.config/kimi/model-rules.json"
        else
            echo "  [DRY-RUN] Would create: ~/.config/kimi/model-rules.json"
        fi
    else
        log_warn "  ⚠ Existing model rules preserved: ~/.config/kimi/model-rules.json"
    fi
}

# Interactive hooks installation prompt
prompt_hooks_install() {
    # Skip prompt if --with-hooks was specified
    if [[ "$WITH_HOOKS" == "true" ]]; then
        return 0
    fi
    
    # Skip if not in a git repository
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        log_warn "Not in a git repository - skipping hooks installation prompt"
        return 1
    fi
    
    echo ""
    log_info "Git hooks can auto-delegate coding tasks to Kimi."
    read -p "Install git hooks for auto-delegation? [Y/n] " -n 1 -r
    echo ""
    
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        return 1
    fi
    
    return 0
}

# Install git hooks
install_hooks_interactive() {
    if ! prompt_hooks_install; then
        log_info "Skipping hooks installation"
        return 0
    fi
    
    log_info "Installing git hooks..."
    
    # Create .kimi directory for project config
    if [[ "$DRY_RUN" == "false" ]]; then
        mkdir -p ".kimi"
    else
        echo "  [DRY-RUN] Would create: .kimi/ directory"
    fi
    
    # Create project hooks config if not exists
    local project_config=".kimi/hooks.json"
    if [[ ! -f "$project_config" ]]; then
        if [[ "$DRY_RUN" == "false" ]]; then
            cat > "$project_config" <<'HOOKS_CONFIG_EOF'
{
  "enabled": true,
  "hooks": {
    "pre-commit": {
      "enabled": true,
      "auto_fix": true,
      "max_files": 10
    },
    "post-checkout": {
      "enabled": true,
      "analyze_changes": true,
      "max_files": 20
    },
    "pre-push": {
      "enabled": true,
      "run_tests": false,
      "auto_fix": false
    }
  }
}
HOOKS_CONFIG_EOF
            log_success "  ✓ Created project hooks config: .kimi/hooks.json"
        else
            echo "  [DRY-RUN] Would create: .kimi/hooks.json"
        fi
    else
        log_warn "  ⚠ Existing project config preserved: .kimi/hooks.json"
    fi
    
    # Install hooks to .git/hooks/
    local git_hooks_dir
    git_hooks_dir=$(git rev-parse --git-path hooks 2>/dev/null)
    
    if [[ -n "$git_hooks_dir" && -d "$git_hooks_dir" ]]; then
        local hooks_source="$SCRIPT_DIR/hooks/hooks"
        
        for hook in pre-commit post-checkout pre-push; do
            if [[ -f "$hooks_source/$hook" ]]; then
                if [[ "$DRY_RUN" == "false" ]]; then
                    # Backup existing hook
                    if [[ -e "$git_hooks_dir/$hook" && ! -L "$git_hooks_dir/$hook" ]]; then
                        backup_config "$git_hooks_dir/$hook"
                    fi
                    
                    # Create symlink
                    ln -sf "$hooks_source/$hook" "$git_hooks_dir/$hook"
                    chmod +x "$hooks_source/$hook"
                    log_success "  ✓ Installed: $hook hook"
                else
                    echo "  [DRY-RUN] Would install: $hook hook → $git_hooks_dir/$hook"
                fi
            fi
        done
    fi
    
    log_success "Hooks installed! Use KIMI_HOOKS_SKIP=1 to bypass when needed."
}

# Verify PATH contains ~/.local/bin
verify_path() {
    log_info "Checking PATH configuration..."
    
    if [[ ":$PATH:" == *":$HOME/.local/bin:"* ]]; then
        log_success "  ✓ ~/.local/bin is in PATH"
        return 0
    else
        log_warn "  ⚠ ~/.local/bin is NOT in PATH"
        echo ""
        echo "  Add this to your shell profile (~/.bashrc, ~/.zshrc, etc.):"
        echo "    export PATH=\"\$HOME/.local/bin:\$PATH\""
        echo ""
        return 1
    fi
}

# Show post-installation summary
show_summary() {
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║   Installation Complete!                               ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    log_info "Installed Components:"
    echo ""
    
    # Check what's installed
    local has_mcp=false
    local has_hooks=false
    local has_model=false
    
    [[ -f "$HOME/.local/bin/kimi-mcp" ]] && has_mcp=true
    [[ -f ".kimi/hooks.json" ]] && has_hooks=true
    [[ -f "$HOME/.local/bin/kimi-model-selector" ]] && has_model=true
    
    if [[ "$has_mcp" == "true" ]]; then
        echo -e "  ${GREEN}✓${NC} MCP Server"
        echo "      Command: kimi-mcp start"
        echo "      Config:   ~/.config/kimi-mcp/config.json"
        echo ""
    fi
    
    if [[ "$has_hooks" == "true" ]]; then
        echo -e "  ${GREEN}✓${NC} Git Hooks"
        echo "      Install:  kimi-hooks install --local"
        echo "      Config:   .kimi/hooks.json"
        echo ""
    fi
    
    if [[ "$has_model" == "true" ]]; then
        echo -e "  ${GREEN}✓${NC} Model Selection Tools"
        echo "      Select:   kimi-model-selector"
        echo "      Estimate: kimi-cost-estimator"
        echo "      Rules:    ~/.config/kimi/model-rules.json"
        echo ""
    fi
    
    echo -e "  ${GREEN}✓${NC} Kimi Wrapper"
    echo "      Script:   $TARGET_DIR/skills/kimi.agent.wrapper.sh"
    echo ""
    
    log_info "Next Steps:"
    echo ""
    
    if [[ "$has_mcp" == "true" ]]; then
        echo "  Test MCP server:"
        echo "    echo '{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"initialize\"}' | kimi-mcp start"
        echo ""
        echo "  Register with Kimi CLI:"
        echo "    kimi-mcp-setup install"
        echo ""
    fi
    
    if [[ "$has_hooks" == "true" ]]; then
        echo "  Configure hooks:"
        echo "    Edit .kimi/hooks.json to customize behavior"
        echo ""
    fi
    
    echo "  Read documentation:"
    echo "    cat .claude/commands/kimi/kimi-mcp.md"
    echo "    cat .claude/commands/kimi/kimi-hooks.md"
    echo ""
    
    # PATH warning if needed
    if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
        log_warn "⚠ Remember to add ~/.local/bin to your PATH!"
        echo "   export PATH=\"\$HOME/.local/bin:\$PATH\""
        echo ""
    fi
    
    log_success "Happy delegating! 🚀"
}

echo -e "${GREEN}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   Climi Installer v${SCRIPT_VERSION}                              ║${NC}"
echo -e "${GREEN}║   Kimi CLI integration for Claude Code                 ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════╝${NC}"
echo ""

# Handle dry-run mode early
if [[ "$DRY_RUN" == "true" ]]; then
    echo -e "${YELLOW}⚡ DRY-RUN MODE: Showing what would be installed${NC}"
    echo ""
fi

# ═══════════════════════════════════════════════════════════
# Prerequisite Checks
# ═══════════════════════════════════════════════════════════

echo -e "${BLUE}Checking prerequisites...${NC}"

MISSING_DEPS=()
KIMI_BIN=""

# Check bash version (v2.0 requires bash 4.0+)
check_bash_version || MISSING_DEPS+=("bash")

# Check for jq (required for v2.0 MCP server)
if ! check_jq; then
    MISSING_DEPS+=("jq")
fi

# Check for kimi CLI (required for Kimi integration)
if KIMI_BIN=$(find_kimi); then
    check_kimi_version "$KIMI_BIN"
else
    MISSING_DEPS+=("kimi-cli")
    echo -e "  ${RED}✗${NC} kimi CLI not found"
    show_kimi_install_instructions
fi

# Check for git (optional but recommended)
if ! command -v git &> /dev/null; then
    echo -e "  ${YELLOW}⚠${NC} git not found (optional, needed for hooks and --diff feature)"
else
    echo -e "  ${GREEN}✓${NC} git $(git --version | cut -d' ' -f3)"
fi

if [ ${#MISSING_DEPS[@]} -gt 0 ]; then
    echo ""
    echo -e "${RED}Missing required dependencies: ${MISSING_DEPS[*]}${NC}"
    echo ""
    echo -e "${YELLOW}Installation instructions:${NC}"

    for dep in "${MISSING_DEPS[@]}"; do
        case "$dep" in
            bash)
                echo -e "  ${CYAN}bash:${NC}"
                echo "    v2.0 requires Bash 4.0 or higher"
                echo "    Please upgrade your bash installation"
                ;;
            jq)
                echo -e "  ${CYAN}jq:${NC}"
                echo "    macOS: brew install jq"
                echo "    Ubuntu/Debian: sudo apt-get install jq"
                echo "    RHEL/CentOS: sudo yum install jq"
                echo "    Windows: choco install jq"
                ;;
            kimi-cli)
                echo -e "  ${CYAN}kimi-cli:${NC}"
                show_kimi_install_instructions
                ;;
        esac
    done
    echo ""
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

echo ""

# ═══════════════════════════════════════════════════════════
# Installation Type Selection (interactive if no CLI args)
# ═══════════════════════════════════════════════════════════

# Only prompt if we're using default (no CLI args specified install mode)
if [[ "$INSTALL_MODE" == "global" && "$TARGET_DIR" == "$DEFAULT_TARGET" && "$FORCE_MODE" == "false" ]]; then
    echo -e "${BLUE}Select installation type:${NC}"
    echo ""
    echo "  1) ${GREEN}Global${NC} - Install to ~/.claude/ (available in all projects)"
    echo "  2) ${CYAN}Project${NC} - Install to current directory"
    echo "  3) ${YELLOW}Custom${NC} - Specify target directory"
    echo ""

    read -p "Choose [1/2/3]: " -n 1 -r INSTALL_TYPE
    echo ""
    echo ""

    case "$INSTALL_TYPE" in
        1)
            TARGET_DIR="$HOME/.claude"
            INSTALL_MODE="global"
            ;;
        2)
            TARGET_DIR="$(pwd)"
            INSTALL_MODE="project"
            ;;
        3)
            read -p "Enter target directory: " TARGET_DIR
            TARGET_DIR="${TARGET_DIR/#\~/$HOME}"  # Expand ~
            INSTALL_MODE="custom"
            ;;
        *)
            echo -e "${RED}Invalid selection${NC}"
            exit 1
            ;;
    esac
fi

echo -e "${BLUE}Installing to:${NC} $TARGET_DIR"
echo -e "${BLUE}Mode:${NC} $INSTALL_MODE"
echo ""

# ═══════════════════════════════════════════════════════════
# Detect Existing Installation
# ═══════════════════════════════════════════════════════════

EXISTING_KIMI=false

# Detect Kimi installation
if [ -f "$TARGET_DIR/skills/kimi.agent.wrapper.sh" ]; then
    EXISTING_KIMI=true
fi

if [ "$EXISTING_KIMI" = true ]; then
    echo -e "${YELLOW}Existing installation detected!${NC}"
    echo -e "  ${CYAN}•${NC} Kimi integration found"
    echo ""
    echo "  This will:"
    echo "  ${GREEN}✓${NC} Update wrapper scripts"
    echo "  ${GREEN}✓${NC} Update role/agent definitions"
    echo "  ${GREEN}✓${NC} Update skill definitions"
    echo "  ${GREEN}✓${NC} Update slash commands"
    echo "  ${GREEN}✓${NC} Update templates"
    echo "  ${YELLOW}⚠${NC} Preserve your .claude/settings.json"
    echo "  ${YELLOW}⚠${NC} Preserve your custom config files"
    echo ""

    if [ "$FORCE_MODE" = false ]; then
        read -p "Create backup before upgrading? (Y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            BACKUP_DIR="$TARGET_DIR/.multi-agent-backup-$(date +%Y%m%d-%H%M%S)"
            mkdir -p "$BACKUP_DIR"

            # Backup Kimi files
            [ -f "$TARGET_DIR/skills/kimi.agent.wrapper.sh" ] && cp "$TARGET_DIR/skills/kimi.agent.wrapper.sh" "$BACKUP_DIR/"
            [ -d "$TARGET_DIR/.kimi/agents" ] && cp -r "$TARGET_DIR/.kimi/agents" "$BACKUP_DIR/"
            [ -d "$TARGET_DIR/.kimi/templates" ] && cp -r "$TARGET_DIR/.kimi/templates" "$BACKUP_DIR/"
            [ -f "$TARGET_DIR/.kimi-version" ] && cp "$TARGET_DIR/.kimi-version" "$BACKUP_DIR/"
            
            # Backup commands
            if [ "$INSTALL_MODE" = "global" ]; then
                if ls "$TARGET_DIR/commands/"*.md &> /dev/null 2>&1; then
                    mkdir -p "$BACKUP_DIR/commands"
                    cp "$TARGET_DIR/commands/"*.md "$BACKUP_DIR/commands/" 2>/dev/null || true
                fi
            else
                if ls "$TARGET_DIR/.claude/commands/"*.md &> /dev/null 2>&1; then
                    mkdir -p "$BACKUP_DIR/commands"
                    cp "$TARGET_DIR/.claude/commands/"*.md "$BACKUP_DIR/commands/" 2>/dev/null || true
                fi
            fi

            echo -e "${GREEN}✓${NC} Backup created at: $BACKUP_DIR"
            echo ""
        fi
    fi
fi

# Confirm (unless force mode)
if [ "$FORCE_MODE" = false ]; then
if [ "$EXISTING_KIMI" = true ]; then
    read -p "Proceed with upgrade? (Y/n) " -n 1 -r
else
    read -p "Proceed with installation? (Y/n) " -n 1 -r
fi
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        echo "Installation cancelled."
        exit 0
    fi
fi

echo ""

# ═══════════════════════════════════════════════════════════
# Installation
# ═══════════════════════════════════════════════════════════

if [ "$EXISTING_KIMI" = true ]; then
    echo -e "${BLUE}Upgrading files...${NC}"
else
    echo -e "${BLUE}Installing files...${NC}"
fi

# Create directories for Kimi
mkdir -p "$TARGET_DIR/.kimi/agents"
mkdir -p "$TARGET_DIR/.kimi/templates"

if [ "$INSTALL_MODE" = "global" ]; then
    mkdir -p "$TARGET_DIR/skills/kimi-delegation"
    mkdir -p "$TARGET_DIR/commands"
    mkdir -p "$TARGET_DIR/commands/kimi"
else
    mkdir -p "$TARGET_DIR/.claude/skills/kimi-delegation"
    mkdir -p "$TARGET_DIR/.claude/commands"
    mkdir -p "$TARGET_DIR/.claude/commands/kimi"
fi

# -- Kimi Installation --

# Copy Kimi wrapper script
if [ -f "$SCRIPT_DIR/skills/kimi.agent.wrapper.sh" ]; then
    cp "$SCRIPT_DIR/skills/kimi.agent.wrapper.sh" "$TARGET_DIR/skills/"
    chmod +x "$TARGET_DIR/skills/kimi.agent.wrapper.sh"
    echo -e "  ${GREEN}✓${NC} Copied Kimi wrapper script"
fi

# Copy Kimi agents (if any exist)
if [ -d "$SCRIPT_DIR/.kimi/agents" ] && ls "$SCRIPT_DIR/.kimi/agents/"*.yaml &> /dev/null 2>&1; then
    cp "$SCRIPT_DIR/.kimi/agents/"*.yaml "$TARGET_DIR/.kimi/agents/"
    echo -e "  ${GREEN}✓${NC} Copied Kimi agents ($(ls -1 "$SCRIPT_DIR/.kimi/agents/"*.yaml 2>/dev/null | wc -l) files)"
fi

# Copy Kimi agent system prompts (MD files)
if [ -d "$SCRIPT_DIR/.kimi/agents" ] && ls "$SCRIPT_DIR/.kimi/agents/"*.md &> /dev/null 2>&1; then
    cp "$SCRIPT_DIR/.kimi/agents/"*.md "$TARGET_DIR/.kimi/agents/"
    echo -e "  ${GREEN}✓${NC} Copied Kimi agent prompts ($(ls -1 "$SCRIPT_DIR/.kimi/agents/"*.md 2>/dev/null | wc -l) files)"
fi

# Copy Kimi templates
if [ -d "$SCRIPT_DIR/.kimi/templates" ] && ls "$SCRIPT_DIR/.kimi/templates/"*.md &> /dev/null 2>&1; then
    cp "$SCRIPT_DIR/.kimi/templates/"*.md "$TARGET_DIR/.kimi/templates/"
    echo -e "  ${GREEN}✓${NC} Copied Kimi templates ($(ls -1 "$SCRIPT_DIR/.kimi/templates/"*.md 2>/dev/null | wc -l) files)"
fi

# Copy Kimi skill definition
if [ -f "$SCRIPT_DIR/dist/.claude/skills/kimi-delegation/SKILL.md" ]; then
    if [ "$INSTALL_MODE" = "global" ]; then
        cp "$SCRIPT_DIR/dist/.claude/skills/kimi-delegation/SKILL.md" "$TARGET_DIR/skills/kimi-delegation/"
    else
        cp "$SCRIPT_DIR/dist/.claude/skills/kimi-delegation/SKILL.md" "$TARGET_DIR/.claude/skills/kimi-delegation/"
    fi
    echo -e "  ${GREEN}✓${NC} Copied Kimi skill definition"
fi

# Copy Kimi slash commands
if [ -d "$SCRIPT_DIR/dist/.claude/commands/kimi" ] && ls "$SCRIPT_DIR/dist/.claude/commands/kimi/"*.md &> /dev/null 2>&1; then
    if [ "$INSTALL_MODE" = "global" ]; then
        cp "$SCRIPT_DIR/dist/.claude/commands/kimi/"*.md "$TARGET_DIR/commands/kimi/"
    else
        cp "$SCRIPT_DIR/dist/.claude/commands/kimi/"*.md "$TARGET_DIR/.claude/commands/kimi/"
    fi
    echo -e "  ${GREEN}✓${NC} Copied Kimi slash commands ($(ls -1 "$SCRIPT_DIR/dist/.claude/commands/kimi/"*.md 2>/dev/null | wc -l) files)"
fi

# Create .kimi-version file
echo "$MIN_KIMI_VERSION" > "$TARGET_DIR/.kimi-version"
echo -e "  ${GREEN}✓${NC} Created .kimi-version file"

# -- MCP Bridge Installation --

install_mcp_bridge() {
    echo -e "${BLUE}Installing MCP Bridge...${NC}"
    
    # Create MCP bridge directories
    mkdir -p "$TARGET_DIR/mcp-bridge/lib"
    mkdir -p "$TARGET_DIR/mcp-bridge/config"
    mkdir -p "$TARGET_DIR/mcp-bridge/tests"
    mkdir -p "$TARGET_DIR/bin"
    
    # Copy MCP bridge files
    if [ -d "$SCRIPT_DIR/mcp-bridge" ]; then
        cp -r "$SCRIPT_DIR/mcp-bridge/lib" "$TARGET_DIR/mcp-bridge/"
        cp -r "$SCRIPT_DIR/mcp-bridge/config" "$TARGET_DIR/mcp-bridge/"
        cp "$SCRIPT_DIR/mcp-bridge/bin/kimi-mcp-server" "$TARGET_DIR/mcp-bridge/bin/"
        chmod +x "$TARGET_DIR/mcp-bridge/bin/kimi-mcp-server"
        echo -e "  ${GREEN}✓${NC} Copied MCP bridge server"
        
        # Copy CLI wrappers
        if [ -f "$SCRIPT_DIR/bin/kimi-mcp" ]; then
            cp "$SCRIPT_DIR/bin/kimi-mcp" "$TARGET_DIR/bin/"
            chmod +x "$TARGET_DIR/bin/kimi-mcp"
            echo -e "  ${GREEN}✓${NC} Copied kimi-mcp CLI"
        fi
        
        if [ -f "$SCRIPT_DIR/bin/kimi-mcp-setup" ]; then
            cp "$SCRIPT_DIR/bin/kimi-mcp-setup" "$TARGET_DIR/bin/"
            chmod +x "$TARGET_DIR/bin/kimi-mcp-setup"
            echo -e "  ${GREEN}✓${NC} Copied kimi-mcp-setup helper"
        fi
        
        # Create user config directory
        mkdir -p "$HOME/.config/kimi-mcp"
        
        # Copy default config if user config doesn't exist
        if [[ ! -f "$HOME/.config/kimi-mcp/config.json" ]]; then
            cp "$TARGET_DIR/mcp-bridge/config/default.json" "$HOME/.config/kimi-mcp/config.json"
            echo -e "  ${GREEN}✓${NC} Created default config at ~/.config/kimi-mcp/config.json"
        else
            echo -e "  ${YELLOW}⚠${NC} Existing ~/.config/kimi-mcp/config.json preserved"
        fi
        
        echo -e "  ${GREEN}✓${NC} MCP Bridge installed"
        echo ""
        echo -e "  ${CYAN}→${NC} Run 'kimi-mcp-setup install' to register with Kimi CLI"
    else
        echo -e "  ${YELLOW}⚠${NC} MCP bridge source not found - skipping"
    fi
}

# -- Hooks System Installation --

install_hooks() {
    log_info "Installing hooks system..."
    
    local hooks_dir="${SCRIPT_DIR}/hooks"
    
    if [[ ! -d "$hooks_dir" ]]; then
        log_warn "Hooks directory not found: $hooks_dir"
        log_warn "Skipping hooks installation"
        return 0
    fi
    
    # Create hooks directories
    mkdir -p "$TARGET_DIR/hooks/config"
    mkdir -p "$TARGET_DIR/hooks/lib"
    mkdir -p "$TARGET_DIR/hooks/hooks"
    
    # Copy config files
    cp "$hooks_dir/config/default.json" "$TARGET_DIR/hooks/config/"
    
    # Copy library files
    cp "$hooks_dir/lib/hooks-config.sh" "$TARGET_DIR/hooks/lib/"
    cp "$hooks_dir/lib/hooks-common.sh" "$TARGET_DIR/hooks/lib/"
    cp "$hooks_dir/lib/install.sh" "$TARGET_DIR/hooks/lib/"
    
    # Copy hook scripts
    cp "$hooks_dir/hooks/pre-commit" "$TARGET_DIR/hooks/hooks/"
    cp "$hooks_dir/hooks/post-checkout" "$TARGET_DIR/hooks/hooks/"
    cp "$hooks_dir/hooks/pre-push" "$TARGET_DIR/hooks/hooks/"
    
    # Make scripts executable
    chmod +x "$TARGET_DIR/hooks/hooks/pre-commit"
    chmod +x "$TARGET_DIR/hooks/hooks/post-checkout"
    chmod +x "$TARGET_DIR/hooks/hooks/pre-push"
    
    # Create user config directory
    mkdir -p "$HOME/.config/kimi"
    
    # Copy default user config if doesn't exist
    if [[ ! -f "$HOME/.config/kimi/hooks.json" ]]; then
        cp "$hooks_dir/config/default.json" "$HOME/.config/kimi/hooks.json"
        log_info "Created default hooks config: ~/.config/kimi/hooks.json"
    fi
    
    # Copy CLI tools
    mkdir -p "$TARGET_DIR/bin"
    if [ -f "$SCRIPT_DIR/bin/kimi-hooks" ]; then
        cp "$SCRIPT_DIR/bin/kimi-hooks" "$TARGET_DIR/bin/"
        chmod +x "$TARGET_DIR/bin/kimi-hooks"
    fi
    if [ -f "$SCRIPT_DIR/bin/kimi-hooks-setup" ]; then
        cp "$SCRIPT_DIR/bin/kimi-hooks-setup" "$TARGET_DIR/bin/"
        chmod +x "$TARGET_DIR/bin/kimi-hooks-setup"
    fi
    
    log_success "Hooks system installed"
    log_info "  Config: ~/.config/kimi/hooks.json"
    log_info "  Run: kimi-hooks install --local (or --global)"
}

# Install v2.0 Components

# MCP Server (v2.0)
install_mcp_server

# Model Selection Tools (v2.0)
install_model_tools

# Hooks System (v2.0)
# Install hooks files to target directory
install_hooks

# Interactive hooks installation (if --with-hooks or user approves)
install_hooks_interactive

# -- Shared Components --

# Copy other slash commands (if provided)
if ls "$SCRIPT_DIR/dist/.claude/commands/"*.md &> /dev/null 2>&1; then
    if [ "$INSTALL_MODE" = "global" ]; then
        cp "$SCRIPT_DIR/dist/.claude/commands/"*.md "$TARGET_DIR/commands/" 2>/dev/null || true
    else
        cp "$SCRIPT_DIR/dist/.claude/commands/"*.md "$TARGET_DIR/.claude/commands/" 2>/dev/null || true
    fi
    echo -e "  ${GREEN}✓${NC} Copied slash commands"
fi

# Handle settings.json (don't overwrite existing)
if [ "$INSTALL_MODE" != "global" ]; then
    SETTINGS_FILE="$TARGET_DIR/.claude/settings.json"
    if [ -f "$SETTINGS_FILE" ]; then
        echo -e "  ${YELLOW}⚠${NC} .claude/settings.json exists - not overwriting"
        echo -e "    ${CYAN}→${NC} See $SCRIPT_DIR/dist/.claude/settings.json for hook examples"
    else
        mkdir -p "$TARGET_DIR/.claude"
        cp "$SCRIPT_DIR/dist/.claude/settings.json" "$SETTINGS_FILE"
        echo -e "  ${GREEN}✓${NC} Copied settings.json with hooks"
    fi
fi

# Verification tests
echo -e "${BLUE}Running verification tests...${NC}"

# Test Kimi wrapper
if [ "$INSTALL_MODE" = "global" ]; then
    KIMI_TEST_OUTPUT=$("$HOME/.claude/skills/kimi.agent.wrapper.sh" --dry-run "test" 2>&1) || true
else
    KIMI_TEST_OUTPUT=$("$TARGET_DIR/skills/kimi.agent.wrapper.sh" --dry-run "test" 2>&1) || true
fi

if echo "$KIMI_TEST_OUTPUT" | grep -q "DRY-RUN"; then
    echo -e "  ${GREEN}✓${NC} Kimi wrapper script works correctly"
else
    echo -e "  ${YELLOW}⚠${NC} Kimi verification inconclusive (kimi CLI may not be installed)"
fi

# Component count
COMPONENT_COUNT=0
[ -f "$TARGET_DIR/skills/kimi.agent.wrapper.sh" ] && ((COMPONENT_COUNT++))
[ -d "$TARGET_DIR/.kimi/templates" ] && COMPONENT_COUNT=$((COMPONENT_COUNT + $(ls -1 "$TARGET_DIR/.kimi/templates/"*.md 2>/dev/null | wc -l)))
[ -f "$HOME/.local/bin/kimi-mcp" ] && ((COMPONENT_COUNT++))
[ -f ".kimi/hooks.json" ] && ((COMPONENT_COUNT++))

if [[ "$DRY_RUN" == "false" ]]; then
    echo -e "${GREEN}Installed ${COMPONENT_COUNT}+ components to ${TARGET_DIR}${NC}"
    echo ""
    
    # Show post-installation summary
    verify_path
    show_summary
else
    echo -e "${YELLOW}Dry-run complete. No changes were made.${NC}"
fi
