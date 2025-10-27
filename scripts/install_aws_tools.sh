#!/usr/bin/env bash
set -euo pipefail

# Installer for AWS CLI v2 (user-space) and jq
# This installs AWS CLI into $HOME/.aws-cli and symlinks binary to $HOME/.local/bin
# Ensures jq exists (via apt or direct download if needed)

log() { echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')] $*"; }

ensure_bin_dir() {
  mkdir -p "$HOME/.local/bin"
  if ! command -v aws >/dev/null 2>&1; then
    log "Installing AWS CLI v2 to user space..."
    tmpdir=$(mktemp -d)
    pushd "$tmpdir" >/dev/null
    curl -sSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip -q awscliv2.zip
    ./aws/install -i "$HOME/.aws-cli" -b "$HOME/.local/bin" || true
    popd >/dev/null
    rm -rf "$tmpdir"
    log "AWS CLI installed to $HOME/.local/bin/aws"
    if ! grep -q "\.local/bin" <<<"$PATH"; then
      log "Add $HOME/.local/bin to your PATH if not already present."
    fi
  else
    log "AWS CLI already installed: $(aws --version 2>&1)"
  fi
}

install_jq() {
  if command -v jq >/dev/null 2>&1; then
    log "jq already present: $(jq --version)"
    return
  fi
  log "Installing jq..."
  if command -v apt-get >/dev/null 2>&1; then
    sudo apt-get update -y && sudo apt-get install -y jq
  else
    # Fallback: download static jq
    tmpdir=$(mktemp -d)
    pushd "$tmpdir" >/dev/null
    curl -sSL -o jq "https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64"
    chmod +x jq
    mv jq "$HOME/.local/bin/jq"
    popd >/dev/null
    rm -rf "$tmpdir"
    log "jq installed to $HOME/.local/bin/jq"
  fi
}

ensure_bin_dir
install_jq

log "Done. Restart your shell or export PATH=\"$HOME/.local/bin:$PATH\""
