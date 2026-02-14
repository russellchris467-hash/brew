#!/bin/bash
set -e

# Fix permissions so Homebrew and Bundler don't complain
sudo chmod -R g-w,o-w /home/linuxbrew
sudo chmod +t -R /home/linuxbrew/

# Install Homebrew's development gems
brew install-bundler-gems --groups=all

# Install Homebrew formulae we might need
brew install shellcheck shfmt gh

# Cleanup
brew cleanup

# Actually tap homebrew/core, no longer done by default
brew tap --force homebrew/core

# Install Claude Code via npm (Node.js is in the Dockerfile)
if ! command -v claude &>/dev/null; then
  npm install -g @anthropic-ai/claude-code
fi

# Install SSH server and start it
sudo pacman -S --noconfirm --needed openssh
sudo ssh-keygen -A 2>/dev/null || true
sudo /usr/sbin/sshd 2>/dev/null || true
