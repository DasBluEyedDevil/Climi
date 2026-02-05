#!/usr/bin/env bash

# Multi-Agent-Workflow Installer
# Installs Gemini Research and Kimi Delegation integrations for Claude Code

set -euo pipefail

# -- Constants ---------------------------------------------------------------
SCRIPT_VERSION="1.0.0"
MIN_KIMI_VERSION="1.7.0"
DEFAULT_TARGET="$HOME/.claude"

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

usage() {
    cat <<'USAGE_EOF'
Multi-Agent-Workflow Installer v1.0.0

Usage: install.sh [OPTIONS]

Options:
  -g, --global        Install to ~/.claude/ (default)
  -l, --local         Install to current directory .claude/
  -t, --target PATH   Install to custom directory
  -f, --force         Overwrite without backup prompt
  -h, --help          Show this help

Examples:
  install.sh                    # Interactive mode (default)
  install.sh --global           # Install to ~/.claude/
  install.sh --local            # Install to ./.claude/
  install.sh --target ~/custom  # Install to ~/custom/
  install.sh --global --force   # Global install, skip backup prompt
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

echo -e "${GREEN}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   Multi-Agent-Workflow Installer v${SCRIPT_VERSION}               ║${NC}"
echo -e "${GREEN}║   Gemini Research + Kimi Delegation for Claude Code    ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════╝${NC}"
echo ""

# ═══════════════════════════════════════════════════════════
# Prerequisite Checks
# ═══════════════════════════════════════════════════════════

echo -e "${BLUE}Checking prerequisites...${NC}"

MISSING_DEPS=()
KIMI_BIN=""

# Check for jq (needed for gemini integration)
if ! command -v jq &> /dev/null; then
    MISSING_DEPS+=("jq")
    echo -e "  ${YELLOW}⚠${NC} jq not found (needed for Gemini integration)"
else
    echo -e "  ${GREEN}✓${NC} jq $(jq --version)"
fi

# Check for gemini CLI (optional - for Gemini integration)
if ! command -v gemini &> /dev/null; then
    echo -e "  ${YELLOW}⚠${NC} gemini CLI not found (needed for Gemini integration)"
else
    echo -e "  ${GREEN}✓${NC} gemini CLI found"
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
    echo -e "  ${YELLOW}⚠${NC} git not found (optional, needed for --diff feature)"
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
            jq)
                echo -e "  ${CYAN}jq:${NC}"
                echo "    Windows (Git Bash): Download from https://stedolan.github.io/jq/"
                echo "    macOS: brew install jq"
                echo "    Linux: sudo apt install jq"
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

EXISTING_GEMINI=false
EXISTING_KIMI=false

# Detect Gemini installation
if [ -f "$TARGET_DIR/skills/gemini.agent.wrapper.sh" ]; then
    EXISTING_GEMINI=true
fi

# Detect Kimi installation
if [ -f "$TARGET_DIR/skills/kimi.agent.wrapper.sh" ]; then
    EXISTING_KIMI=true
fi

if [ "$EXISTING_GEMINI" = true ] || [ "$EXISTING_KIMI" = true ]; then
    echo -e "${YELLOW}Existing installation detected!${NC}"
    [ "$EXISTING_GEMINI" = true ] && echo -e "  ${CYAN}•${NC} Gemini integration found"
    [ "$EXISTING_KIMI" = true ] && echo -e "  ${CYAN}•${NC} Kimi integration found"
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

            # Backup Gemini files
            [ -f "$TARGET_DIR/skills/gemini.agent.wrapper.sh" ] && cp "$TARGET_DIR/skills/gemini.agent.wrapper.sh" "$BACKUP_DIR/"
            [ -f "$TARGET_DIR/skills/gemini-parse.sh" ] && cp "$TARGET_DIR/skills/gemini-parse.sh" "$BACKUP_DIR/"
            [ -f "$TARGET_DIR/skills/gemini.ps1" ] && cp "$TARGET_DIR/skills/gemini.ps1" "$BACKUP_DIR/"
            [ -d "$TARGET_DIR/.gemini/roles" ] && cp -r "$TARGET_DIR/.gemini/roles" "$BACKUP_DIR/"
            [ -f "$TARGET_DIR/.gemini/config" ] && cp "$TARGET_DIR/.gemini/config" "$BACKUP_DIR/"
            [ -f "$TARGET_DIR/GeminiContext.md" ] && cp "$TARGET_DIR/GeminiContext.md" "$BACKUP_DIR/"
            
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
    if [ "$EXISTING_GEMINI" = true ] || [ "$EXISTING_KIMI" = true ]; then
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

if [ "$EXISTING_GEMINI" = true ] || [ "$EXISTING_KIMI" = true ]; then
    echo -e "${BLUE}Upgrading files...${NC}"
else
    echo -e "${BLUE}Installing files...${NC}"
fi

# Create directories for Gemini
mkdir -p "$TARGET_DIR/skills"
mkdir -p "$TARGET_DIR/.gemini/roles"
mkdir -p "$TARGET_DIR/.gemini/templates"

# Create directories for Kimi
mkdir -p "$TARGET_DIR/.kimi/agents"
mkdir -p "$TARGET_DIR/.kimi/templates"

if [ "$INSTALL_MODE" = "global" ]; then
    mkdir -p "$TARGET_DIR/skills/gemini-research"
    mkdir -p "$TARGET_DIR/skills/kimi-delegation"
    mkdir -p "$TARGET_DIR/commands"
    mkdir -p "$TARGET_DIR/commands/kimi"
else
    mkdir -p "$TARGET_DIR/.claude/skills/gemini-research"
    mkdir -p "$TARGET_DIR/.claude/skills/kimi-delegation"
    mkdir -p "$TARGET_DIR/.claude/commands"
    mkdir -p "$TARGET_DIR/.claude/commands/kimi"
fi

# -- Gemini Installation --

# Copy Gemini wrapper scripts
if [ -f "$SCRIPT_DIR/skills/gemini.agent.wrapper.sh" ]; then
    cp "$SCRIPT_DIR/skills/gemini.agent.wrapper.sh" "$TARGET_DIR/skills/"
    cp "$SCRIPT_DIR/skills/gemini-parse.sh" "$TARGET_DIR/skills/" 2>/dev/null || true
    cp "$SCRIPT_DIR/skills/gemini.ps1" "$TARGET_DIR/skills/" 2>/dev/null || true
    chmod +x "$TARGET_DIR/skills/gemini"*.sh 2>/dev/null || true
    echo -e "  ${GREEN}✓${NC} Copied Gemini wrapper scripts"
fi

# Copy Gemini roles
if [ -d "$SCRIPT_DIR/.gemini/roles" ] && ls "$SCRIPT_DIR/.gemini/roles/"*.md &> /dev/null 2>&1; then
    cp "$SCRIPT_DIR/.gemini/roles/"*.md "$TARGET_DIR/.gemini/roles/"
    echo -e "  ${GREEN}✓${NC} Copied Gemini roles ($(ls -1 "$SCRIPT_DIR/.gemini/roles/"*.md 2>/dev/null | wc -l) files)"
fi

# Copy Gemini templates (if any exist)
if [ -d "$SCRIPT_DIR/.gemini/templates" ] && ls "$SCRIPT_DIR/.gemini/templates/"*.md &> /dev/null 2>&1; then
    cp "$SCRIPT_DIR/.gemini/templates/"*.md "$TARGET_DIR/.gemini/templates/"
    echo -e "  ${GREEN}✓${NC} Copied Gemini templates"
fi

# Copy Gemini config example (don't overwrite existing config)
if [ -f "$SCRIPT_DIR/.gemini/config.example" ]; then
    cp "$SCRIPT_DIR/.gemini/config.example" "$TARGET_DIR/.gemini/"
    echo -e "  ${GREEN}✓${NC} Copied config.example"
fi
if [ -f "$TARGET_DIR/.gemini/config" ]; then
    echo -e "  ${YELLOW}⚠${NC} Existing .gemini/config preserved"
fi

# Copy Gemini context file
if [ -f "$SCRIPT_DIR/GeminiContext.md" ]; then
    cp "$SCRIPT_DIR/GeminiContext.md" "$TARGET_DIR/"
    echo -e "  ${GREEN}✓${NC} Copied GeminiContext.md"
fi

# Copy Gemini skill definition
if [ -f "$SCRIPT_DIR/.claude/skills/gemini-research/SKILL.md" ]; then
    if [ "$INSTALL_MODE" = "global" ]; then
        cp "$SCRIPT_DIR/.claude/skills/gemini-research/SKILL.md" "$TARGET_DIR/skills/gemini-research/"
    else
        cp "$SCRIPT_DIR/.claude/skills/gemini-research/SKILL.md" "$TARGET_DIR/.claude/skills/gemini-research/"
    fi
    echo -e "  ${GREEN}✓${NC} Copied Gemini skill definition"
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

# Copy Kimi templates
if [ -d "$SCRIPT_DIR/.kimi/templates" ] && ls "$SCRIPT_DIR/.kimi/templates/"*.md &> /dev/null 2>&1; then
    cp "$SCRIPT_DIR/.kimi/templates/"*.md "$TARGET_DIR/.kimi/templates/"
    echo -e "  ${GREEN}✓${NC} Copied Kimi templates ($(ls -1 "$SCRIPT_DIR/.kimi/templates/"*.md 2>/dev/null | wc -l) files)"
fi

# Copy Kimi skill definition
if [ -f "$SCRIPT_DIR/.claude/skills/kimi-delegation/SKILL.md" ]; then
    if [ "$INSTALL_MODE" = "global" ]; then
        cp "$SCRIPT_DIR/.claude/skills/kimi-delegation/SKILL.md" "$TARGET_DIR/skills/kimi-delegation/"
    else
        cp "$SCRIPT_DIR/.claude/skills/kimi-delegation/SKILL.md" "$TARGET_DIR/.claude/skills/kimi-delegation/"
    fi
    echo -e "  ${GREEN}✓${NC} Copied Kimi skill definition"
fi

# Copy Kimi slash commands
if [ -d "$SCRIPT_DIR/.claude/commands/kimi" ] && ls "$SCRIPT_DIR/.claude/commands/kimi/"*.md &> /dev/null 2>&1; then
    if [ "$INSTALL_MODE" = "global" ]; then
        cp "$SCRIPT_DIR/.claude/commands/kimi/"*.md "$TARGET_DIR/commands/kimi/"
    else
        cp "$SCRIPT_DIR/.claude/commands/kimi/"*.md "$TARGET_DIR/.claude/commands/kimi/"
    fi
    echo -e "  ${GREEN}✓${NC} Copied Kimi slash commands ($(ls -1 "$SCRIPT_DIR/.claude/commands/kimi/"*.md 2>/dev/null | wc -l) files)"
fi

# Create .kimi-version file
echo "$MIN_KIMI_VERSION" > "$TARGET_DIR/.kimi-version"
echo -e "  ${GREEN}✓${NC} Created .kimi-version file"

# -- Shared Components --

# Copy other slash commands (if provided)
if ls "$SCRIPT_DIR/.claude/commands/"*.md &> /dev/null 2>&1; then
    if [ "$INSTALL_MODE" = "global" ]; then
        cp "$SCRIPT_DIR/.claude/commands/"*.md "$TARGET_DIR/commands/" 2>/dev/null || true
    else
        cp "$SCRIPT_DIR/.claude/commands/"*.md "$TARGET_DIR/.claude/commands/" 2>/dev/null || true
    fi
    echo -e "  ${GREEN}✓${NC} Copied slash commands"
fi

# Handle settings.json (don't overwrite existing)
if [ "$INSTALL_MODE" != "global" ]; then
    SETTINGS_FILE="$TARGET_DIR/.claude/settings.json"
    if [ -f "$SETTINGS_FILE" ]; then
        echo -e "  ${YELLOW}⚠${NC} .claude/settings.json exists - not overwriting"
        echo -e "    ${CYAN}→${NC} See $SCRIPT_DIR/.claude/settings.json for hook examples"
    else
        mkdir -p "$TARGET_DIR/.claude"
        cp "$SCRIPT_DIR/.claude/settings.json" "$SETTINGS_FILE"
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

# Test Gemini wrapper
if [ -f "$TARGET_DIR/skills/gemini.agent.wrapper.sh" ]; then
    if [ "$INSTALL_MODE" = "global" ]; then
        GEMINI_TEST_OUTPUT=$("$HOME/.claude/skills/gemini.agent.wrapper.sh" --dry-run "test" 2>&1) || true
    else
        GEMINI_TEST_OUTPUT=$("$TARGET_DIR/skills/gemini.agent.wrapper.sh" --dry-run "test" 2>&1) || true
    fi

    if echo "$GEMINI_TEST_OUTPUT" | grep -q "DRY RUN"; then
        echo -e "  ${GREEN}✓${NC} Gemini wrapper script works correctly"
    else
        echo -e "  ${YELLOW}⚠${NC} Gemini verification inconclusive"
    fi
fi

echo ""

# Component count
COMPONENT_COUNT=0
[ -f "$TARGET_DIR/skills/kimi.agent.wrapper.sh" ] && ((COMPONENT_COUNT++))
[ -f "$TARGET_DIR/skills/gemini.agent.wrapper.sh" ] && ((COMPONENT_COUNT++))
[ -d "$TARGET_DIR/.kimi/templates" ] && COMPONENT_COUNT=$((COMPONENT_COUNT + $(ls -1 "$TARGET_DIR/.kimi/templates/"*.md 2>/dev/null | wc -l)))
[ -d "$TARGET_DIR/.gemini/roles" ] && COMPONENT_COUNT=$((COMPONENT_COUNT + $(ls -1 "$TARGET_DIR/.gemini/roles/"*.md 2>/dev/null | wc -l)))

echo -e "${GREEN}Installed ${COMPONENT_COUNT}+ components to ${TARGET_DIR}${NC}"
echo ""
echo -e "${GREEN}Done!${NC}"
