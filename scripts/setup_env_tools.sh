#!/usr/bin/env bash

set -euo pipefail

BASE_DIR="${BASE_DIR:-$HOME}"
MINICONDA_DIR="${MINICONDA_DIR:-$BASE_DIR/miniconda3}"
TOOLS_ENV_DIR="${TOOLS_ENV_DIR:-$BASE_DIR/conda-usr}"
NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
NODE_VERSION="${NODE_VERSION:-lts/*}"
INSTALLER_DIR="${INSTALLER_DIR:-/tmp}"

TOOLS=(
  gpustat
  ncdu
  ripgrep
  fd-find
  zoxide
  fzf
  eza
  dust
  bat
  git-delta
  sd
  hyperfine
  tldr
  yazi
  unzip
  jq
  iotop
  speedtest-cli
  vim
  shellcheck
  htop
)

log() {
  printf '[setup_env_tools] %s\n' "$*"
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    log "Missing required command: $1"
    exit 1
  fi
}

detect_miniconda_arch() {
  local arch
  arch="$(uname -m)"

  case "$arch" in
    x86_64)
      printf 'x86_64'
      ;;
    aarch64|arm64)
      printf 'aarch64'
      ;;
    *)
      log "Unsupported architecture: $arch"
      exit 1
      ;;
  esac
}

install_miniconda() {
  if [[ -x "$MINICONDA_DIR/bin/conda" ]]; then
    log "Miniconda already installed at $MINICONDA_DIR"
    return
  fi

  local arch installer installer_path
  arch="$(detect_miniconda_arch)"
  installer="Miniconda3-latest-Linux-${arch}.sh"
  installer_path="$INSTALLER_DIR/$installer"

  require_cmd wget

  log "Downloading $installer"
  wget -q --show-progress "https://repo.anaconda.com/miniconda/${installer}" -O "$installer_path"

  log "Installing Miniconda to $MINICONDA_DIR"
  bash "$installer_path" -b -p "$MINICONDA_DIR"
}

init_conda() {
  if [[ ! -f "$MINICONDA_DIR/etc/profile.d/conda.sh" ]]; then
    log "Cannot find conda init script at $MINICONDA_DIR/etc/profile.d/conda.sh"
    exit 1
  fi

  # shellcheck disable=SC1091
  source "$MINICONDA_DIR/etc/profile.d/conda.sh"
}

ensure_tools_env() {
  if [[ -d "$TOOLS_ENV_DIR" ]]; then
    log "Tool environment already exists at $TOOLS_ENV_DIR"
    return
  fi

  log "Creating tool environment at $TOOLS_ENV_DIR"
  conda create -p "$TOOLS_ENV_DIR" python=3.12 -y
}

activate_tools_env() {
  conda activate "$TOOLS_ENV_DIR"
}

accept_conda_tos() {
  conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/main
  conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/r
}

install_tools() {
  log "Installing tools into $TOOLS_ENV_DIR"
  conda install -c conda-forge -y "${TOOLS[@]}"
}

install_uv() {
  if command -v uv >/dev/null 2>&1; then
    log "uv already installed"
    return
  fi

  require_cmd curl

  log "Installing uv"
  curl -LsSf https://astral.sh/uv/install.sh | sh
}

install_nvm() {
  if [[ -s "$NVM_DIR/nvm.sh" ]]; then
    log "nvm already installed at $NVM_DIR"
    return
  fi

  require_cmd curl

  log "Installing nvm to $NVM_DIR"
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.4/install.sh | NVM_DIR="$NVM_DIR" PROFILE=/dev/null bash
}

load_nvm() {
  if [[ ! -s "$NVM_DIR/nvm.sh" ]]; then
    log "Cannot find nvm init script at $NVM_DIR/nvm.sh"
    exit 1
  fi

  export NVM_DIR
  # shellcheck disable=SC1090
  source "$NVM_DIR/nvm.sh"
}

use_node_version() {
  load_nvm

  log "Installing Node.js $NODE_VERSION via nvm"
  nvm install "$NODE_VERSION"
  nvm alias default "$NODE_VERSION"
  nvm use default
}

install_node() {
  use_node_version
}

install_codex() {
  use_node_version

  if command -v codex >/dev/null 2>&1; then
    log "codex already installed"
    return
  fi

  log "Installing Codex CLI"
  npm install -g @openai/codex
}

main() {
  install_miniconda
  init_conda

  log "Active conda base:"
  conda info | grep "base environment" || true

  # Accept ToS before any package-solving command such as `conda create`.
  accept_conda_tos
  ensure_tools_env
  activate_tools_env
  install_tools
  install_uv
  install_nvm
  install_node
  install_codex

  log "Setup complete. Current tool environment: $TOOLS_ENV_DIR"
}

main "$@"
