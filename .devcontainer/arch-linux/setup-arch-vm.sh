#!/bin/bash
# Setup script for Claude Code on an Arch Linux VM (UTM/QEMU).
#
# Usage:
#   bash setup-arch-vm.sh
#
# Prerequisites:
#   - Arch Linux installation (x86_64 or aarch64) running in UTM
#   - Internet connectivity
#   - A non-root user with sudo privileges
#
# What this script does:
#   1. Updates system and installs core dependencies
#   2. Installs Node.js (required by Claude Code)
#   3. Installs Claude Code via npm
#   4. Installs UTM/QEMU guest agents (clipboard sharing, display resize)
#   5. Verifies the setup
set -euo pipefail

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

# ── 1. System update and core packages ───────────────────────────────────────

info "Updating system and installing core packages..."

sudo pacman -Syu --noconfirm

sudo pacman -S --noconfirm --needed \
  base-devel \
  curl \
  git \
  openssh \
  ca-certificates \
  jq \
  less \
  unzip \
  which

# ── 2. Install Node.js (required by Claude Code) ────────────────────────────

info "Installing Node.js and npm..."
sudo pacman -S --noconfirm --needed nodejs npm

node_major="$(node --version | sed 's/^v//' | cut -d. -f1)"
if [[ "$node_major" -lt 18 ]]; then
  warn "Node.js $(node --version) is below v18. Claude Code needs >= 18."
  warn "Install a newer version: sudo pacman -S nodejs-lts-iron"
fi

# ── 3. Install Claude Code ───────────────────────────────────────────────────

info "Installing Claude Code..."

if command_exists claude; then
  info "Claude Code already installed: $(claude --version 2>/dev/null || echo 'unknown version')"
  info "Updating to latest..."
  npm update -g @anthropic-ai/claude-code || npm install -g @anthropic-ai/claude-code
else
  npm install -g @anthropic-ai/claude-code
fi

# ── 4. UTM/QEMU guest agents (clipboard, display auto-resize) ───────────────

info "Installing UTM/QEMU guest utilities..."

sudo pacman -S --noconfirm --needed \
  spice-vdagent \
  qemu-guest-agent || warn "Guest agent packages not available (non-fatal)."

# Enable services so clipboard sharing and display resize work in UTM
sudo systemctl enable --now spice-vdagentd.service 2>/dev/null || true
sudo systemctl enable --now qemu-guest-agent.service 2>/dev/null || true

# ── 5. Verify setup ──────────────────────────────────────────────────────────

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
echo "  node:     $(node --version 2>/dev/null)"
echo "  npm:      $(npm --version 2>/dev/null)"
echo "  claude:   $(claude --version 2>/dev/null || echo 'not found')"
echo ""
echo "──────────────────────────────────────────"

echo ""
info "Setup complete!"
echo ""
echo "Next steps:"
echo "  1. Open a new terminal (or run: source ~/.bashrc)"
echo "  2. Run 'claude' to launch Claude Code"
echo "  3. If clipboard isn't working in UTM, log out and back in"
echo "     for spice-vdagent to take effect"
echo ""
