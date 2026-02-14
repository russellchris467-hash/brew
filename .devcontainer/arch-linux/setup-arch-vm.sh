#!/bin/bash
# Setup script for Homebrew development with Claude Code on an Arch Linux VM (UTM/QEMU).
#
# Usage:
#   curl -fsSL <raw-url>/setup-arch-vm.sh | bash
#   # or
#   bash setup-arch-vm.sh
#
# Prerequisites:
#   - A fresh or existing Arch Linux installation (x86_64 or aarch64)
#   - Internet connectivity
#   - A non-root user with sudo privileges
#
# What this script does:
#   1. Installs system dependencies required by Homebrew
#   2. Installs Homebrew itself
#   3. Installs development gems and tooling
#   4. Configures shell environment (bash/zsh)
#   5. Installs Claude Code (Node.js + npm)
#   6. Verifies the setup
set -euo pipefail

readonly HOMEBREW_PREFIX="/home/linuxbrew/.linuxbrew"
readonly SCRIPT_NAME="$(basename "$0")"

# ── Helpers ───────────────────────────────────────────────────────────────────

info()  { printf '\033[1;34m==> %s\033[0m\n' "$*"; }
warn()  { printf '\033[1;33mWarning: %s\033[0m\n' "$*"; }
error() { printf '\033[1;31mError: %s\033[0m\n' "$*" >&2; exit 1; }

command_exists() { command -v "$1" &>/dev/null; }

# ── Pre-flight checks ────────────────────────────────────────────────────────

if [[ $EUID -eq 0 ]]; then
  error "Do not run this script as root. Run as a normal user with sudo access."
fi

if ! command_exists pacman; then
  error "This script is intended for Arch Linux (pacman not found)."
fi

# ── 1. System dependencies ───────────────────────────────────────────────────

info "Installing Arch Linux system dependencies..."

sudo pacman -Syu --noconfirm

sudo pacman -S --noconfirm --needed \
  base-devel \
  procps-ng \
  curl \
  file \
  git \
  openssh \
  sudo \
  ca-certificates \
  jq \
  less \
  unzip \
  which \
  zsh

# ── 2. Install Node.js (needed for Claude Code) ─────────────────────────────

if ! command_exists node; then
  info "Installing Node.js..."
  sudo pacman -S --noconfirm --needed nodejs npm
fi

node_major="$(node --version | sed 's/^v//' | cut -d. -f1)"
if [[ "$node_major" -lt 18 ]]; then
  warn "Node.js version $(node --version) is older than v18. Claude Code requires Node.js >= 18."
  warn "Consider installing a newer version via nvm or pacman."
fi

# ── 3. Install Homebrew ──────────────────────────────────────────────────────

if ! command_exists brew; then
  info "Installing Homebrew..."
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
else
  info "Homebrew already installed, updating..."
  brew update
fi

# Configure shell environment for Homebrew
configure_shell() {
  local rcfile="$1"
  local shellenv_line='eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"'

  if [[ -f "$rcfile" ]] && grep -qF "brew shellenv" "$rcfile"; then
    return 0
  fi

  info "Adding Homebrew to ${rcfile}..."
  {
    echo ""
    echo "# Homebrew"
    echo "$shellenv_line"
  } >> "$rcfile"
}

configure_shell "${HOME}/.bashrc"
[[ -f "${HOME}/.zshrc" || "$SHELL" == */zsh ]] && configure_shell "${HOME}/.zshrc"

# Source Homebrew for the rest of this script
eval "$("${HOMEBREW_PREFIX}/bin/brew" shellenv)"

# ── 4. Clone and set up the Homebrew/brew source for development ─────────────

info "Setting up Homebrew/brew development checkout..."

BREW_REPO="$(brew --repository)"

# Ensure we are on a development-ready checkout
if ! git -C "$BREW_REPO" remote get-url origin | grep -q "Homebrew/brew"; then
  warn "Homebrew repo remote doesn't point to Homebrew/brew. Skipping dev setup."
else
  info "Homebrew repo at ${BREW_REPO}"

  # Install development gems (style, typecheck, tests, etc.)
  info "Installing Homebrew development gems..."
  brew install-bundler-gems --groups=all || warn "Some gem groups failed to install (non-fatal)."

  # Install useful development formulae
  info "Installing development formulae..."
  brew install shellcheck shfmt gh || true
fi

# ── 5. Install Claude Code ───────────────────────────────────────────────────

info "Installing Claude Code..."

if command_exists claude; then
  info "Claude Code already installed: $(claude --version 2>/dev/null || echo 'unknown version')"
else
  npm install -g @anthropic-ai/claude-code
fi

# ── 6. Configure SPICE/QEMU guest agent (optional, for UTM clipboard/resize)

if command_exists pacman; then
  info "Installing UTM/QEMU guest utilities for better VM integration..."
  sudo pacman -S --noconfirm --needed \
    spice-vdagent \
    qemu-guest-agent || warn "Guest agent packages not available (non-fatal)."

  # Enable services if available
  sudo systemctl enable --now spice-vdagentd.service 2>/dev/null || true
  sudo systemctl enable --now qemu-guest-agent.service 2>/dev/null || true
fi

# ── 7. Verify setup ──────────────────────────────────────────────────────────

info "Verifying setup..."

echo ""
echo "──────────────────────────────────────────"
echo " System Info"
echo "──────────────────────────────────────────"
echo "  Arch:     $(uname -m)"
echo "  Kernel:   $(uname -r)"
echo "  Shell:    ${SHELL}"
echo ""
echo " Tool Versions"
echo "──────────────────────────────────────────"
echo "  git:      $(git --version 2>/dev/null | awk '{print $3}')"
echo "  ruby:     $(ruby --version 2>/dev/null | awk '{print $2}')"
echo "  node:     $(node --version 2>/dev/null)"
echo "  brew:     $(brew --version 2>/dev/null | head -1)"
echo "  claude:   $(claude --version 2>/dev/null || echo 'not found')"
echo ""
echo "──────────────────────────────────────────"

# Run brew doctor for a health check
info "Running brew doctor..."
brew doctor || warn "brew doctor reported warnings (see above)."

echo ""
info "Setup complete!"
echo ""
echo "Next steps:"
echo "  1. Open a new terminal (or run: source ~/.bashrc)"
echo "  2. Run 'claude' to start Claude Code"
echo "  3. Navigate to $(brew --repository) to work on Homebrew source"
echo "  4. The .claude/settings.json hooks are already configured in the repo"
echo ""
