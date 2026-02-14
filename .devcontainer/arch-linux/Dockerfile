FROM archlinux:latest

# Deterministic UID (matches Ubuntu Dockerfile convention)
ENV USER_ID=1000

# Install system dependencies for Homebrew and development
# We don't pin versions on Arch — rolling release model.
RUN pacman -Syu --noconfirm \
  && pacman -S --noconfirm --needed \
    base-devel \
    ca-certificates \
    curl \
    file \
    gawk \
    git \
    jq \
    less \
    make \
    nodejs \
    npm \
    openssh \
    patch \
    procps-ng \
    sudo \
    unzip \
    which \
    zsh \
  && pacman -Scc --noconfirm \
  && useradd -u "${USER_ID}" --create-home --shell /bin/bash --user-group linuxbrew \
  && echo 'linuxbrew ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers \
  && su - linuxbrew -c 'mkdir -p ~/.linuxbrew'

USER linuxbrew
COPY --chown=linuxbrew:linuxbrew . /home/linuxbrew/.linuxbrew/Homebrew
ENV PATH="/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin:${PATH}" \
    XDG_CACHE_HOME=/home/linuxbrew/.cache
WORKDIR /home/linuxbrew

RUN --mount=type=cache,target=/tmp/homebrew-core,uid="${USER_ID}",sharing=locked \
  git clone https://github.com/homebrew/homebrew-core /tmp/homebrew-core || { cd /tmp/homebrew-core && git pull; } \
  && mkdir -p /home/linuxbrew/.linuxbrew/Homebrew/Library/Taps/homebrew/homebrew-core \
  && cp -r /tmp/homebrew-core /home/linuxbrew/.linuxbrew/Homebrew/Library/Taps/homebrew/

RUN --mount=type=cache,target=/home/linuxbrew/.cache,uid="${USER_ID}" \
  --mount=type=cache,target=/home/linuxbrew/.bundle,uid="${USER_ID}" \
  mkdir -p \
    .linuxbrew/bin \
    .linuxbrew/etc \
    .linuxbrew/include \
    .linuxbrew/lib \
    .linuxbrew/opt \
    .linuxbrew/sbin \
    .linuxbrew/share \
    .linuxbrew/var/homebrew/linked \
    .linuxbrew/Cellar \
  && ln -s ../Homebrew/bin/brew .linuxbrew/bin/brew \
  && git -C .linuxbrew/Homebrew remote set-url origin https://github.com/Homebrew/brew \
  && git -C .linuxbrew/Homebrew fetch origin \
  && HOMEBREW_NO_ANALYTICS=1 HOMEBREW_NO_AUTO_UPDATE=1 brew tap --force homebrew/core \
  && brew install-bundler-gems --groups=all \
  && brew cleanup \
  && { git -C .linuxbrew/Homebrew config --unset gc.auto; true; } \
  && { git -C .linuxbrew/Homebrew config --unset homebrew.devcmdrun; true; } \
  && touch .linuxbrew/.homebrewdocker
