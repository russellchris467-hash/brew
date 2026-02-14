FROM archlinux:latest

ENV USER_ID=1000

# Install system dependencies and Node.js for Claude Code
RUN pacman -Syu --noconfirm \
  && pacman -S --noconfirm --needed \
    base-devel \
    ca-certificates \
    curl \
    git \
    jq \
    less \
    nodejs \
    npm \
    openssh \
    spice-vdagent \
    qemu-guest-agent \
    sudo \
    unzip \
    which \
  && pacman -Scc --noconfirm \
  && useradd -u "${USER_ID}" --create-home --shell /bin/bash --user-group archuser \
  && echo 'archuser ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

# Install Claude Code
RUN npm install -g @anthropic-ai/claude-code

USER archuser
WORKDIR /home/archuser
