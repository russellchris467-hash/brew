#!/bin/bash
set -euo pipefail

# Only run in remote Claude Code web sessions
if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

BREW_DIR="$CLAUDE_PROJECT_DIR"
HOMEBREW_LIB="$BREW_DIR/Library/Homebrew"
VENDOR_DIR="$HOMEBREW_LIB/vendor"
PORTABLE_RUBY_VERSION=$(cat "$VENDOR_DIR/portable-ruby-version")
PORTABLE_RUBY_DIR="$VENDOR_DIR/portable-ruby"
PORTABLE_RUBY_BIN="$PORTABLE_RUBY_DIR/$PORTABLE_RUBY_VERSION/bin/ruby"
BUNDLE_BIN="$PORTABLE_RUBY_DIR/$PORTABLE_RUBY_VERSION/bin/bundle"

echo "==> Setting up Homebrew development environment..."

# Export SSL_CERT_FILE for this session (needed for Ruby/bundler SSL through proxy)
if [ -f "/etc/ssl/certs/ca-certificates.crt" ]; then
  echo 'export SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt' >> "$CLAUDE_ENV_FILE"
  export SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt
fi

# Install portable Ruby if not already present
if [ ! -f "$PORTABLE_RUBY_BIN" ]; then
  echo "==> Downloading portable Ruby $PORTABLE_RUBY_VERSION..."

  TARBALL="/tmp/portable-ruby-${PORTABLE_RUBY_VERSION}.tar.gz"
  TARBALL_URL="https://github.com/Homebrew/homebrew-portable-ruby/releases/download/${PORTABLE_RUBY_VERSION}/portable-ruby-${PORTABLE_RUBY_VERSION}.x86_64_linux.bottle.tar.gz"

  curl -fsSL "$TARBALL_URL" -o "$TARBALL"

  echo "==> Extracting portable Ruby $PORTABLE_RUBY_VERSION..."
  mkdir -p "$PORTABLE_RUBY_DIR"
  # Tarball structure is portable-ruby/$VERSION/..., extract in vendor/ to get portable-ruby/$VERSION/
  tar xzf "$TARBALL" -C "$VENDOR_DIR"
  rm -f "$TARBALL"
fi

# Create/update the 'current' symlink
ln -sfn "$PORTABLE_RUBY_VERSION" "$PORTABLE_RUBY_DIR/current"

# Get OpenSSL default cert path from portable Ruby and set up Anthropic proxy CA cert
OPENSSL_CERT_PATH=$("$PORTABLE_RUBY_BIN" -e "require 'openssl'; puts OpenSSL::X509::DEFAULT_CERT_FILE" 2>/dev/null || true)
if [ -n "$OPENSSL_CERT_PATH" ] && [ -f "/etc/ssl/certs/ca-certificates.crt" ] && [ ! -f "$OPENSSL_CERT_PATH" ]; then
  mkdir -p "$(dirname "$OPENSSL_CERT_PATH")"
  cp /etc/ssl/certs/ca-certificates.crt "$OPENSSL_CERT_PATH"
fi

# Configure bundler ssl-ca-cert for brew's filtered environment
cd "$HOMEBREW_LIB"
BUNDLE_CONFIG="$HOMEBREW_LIB/.bundle/config"
if ! grep -q "BUNDLE_SSL___CA___CERT" "$BUNDLE_CONFIG" 2>/dev/null; then
  "$BUNDLE_BIN" config set ssl-ca-cert /etc/ssl/certs/ca-certificates.crt
fi

# Compute all optional gem groups from Gemfile (brew tests installs all valid groups)
ALL_GROUPS=$(grep "^group" "$HOMEBREW_LIB/Gemfile" \
  | grep -oE ':[a-z_]+' | tr -d ':' | sort -u | tr '\n' ' ' | sed 's/ $//')

# Determine gem path (Ruby API version subfolder)
RUBY_API_VERSION=$("$PORTABLE_RUBY_BIN" -e "puts RbConfig::CONFIG['ruby_version']")
GEM_HOME="$HOMEBREW_LIB/vendor/bundle/ruby/$RUBY_API_VERSION"

# Install all gem groups via bundle install (uses SSL_CERT_FILE set above)
echo "==> Installing Homebrew gem dependencies (groups: $ALL_GROUPS)..."
SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt \
  BUNDLE_GEMFILE="$HOMEBREW_LIB/Gemfile" \
  BUNDLE_WITH="$ALL_GROUPS" \
  BUNDLE_FROZEN="true" \
  GEM_HOME="$GEM_HOME" \
  GEM_PATH="$GEM_HOME" \
  "$BUNDLE_BIN" install

echo "==> Homebrew development environment ready."
