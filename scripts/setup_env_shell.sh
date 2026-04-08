#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dotfiles}"
OH_MY_ZSH_DIR="${ZSH:-$HOME/.oh-my-zsh}"
ZSH_CUSTOM_DIR="${ZSH_CUSTOM:-$OH_MY_ZSH_DIR/custom}"

log() {
  printf '[setup_env_shell] %s\n' "$*"
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    log "Missing required command: $1"
    exit 1
  fi
}

append_if_missing() {
  local target_file="$1"
  local marker="$2"
  local block="$3"

  mkdir -p "$(dirname "$target_file")"
  touch "$target_file"

  if grep -Fq "$marker" "$target_file"; then
    log "Block already present in $target_file"
    return
  fi

  printf '\n%s\n' "$block" >> "$target_file"
  log "Updated $target_file"
}

clone_or_update_repo() {
  local repo_url="$1"
  local destination="$2"

  if [[ -d "$destination/.git" ]]; then
    log "Updating $destination"
    git -C "$destination" pull --ff-only
    return
  fi

  if [[ -e "$destination" ]]; then
    log "Skipping $destination because it exists and is not a git repo"
    return
  fi

  log "Cloning $repo_url into $destination"
  git clone --depth=1 "$repo_url" "$destination"
}

download_if_missing() {
  local url="$1"
  local destination="$2"

  if [[ -f "$destination" ]]; then
    log "Keeping existing $destination"
    return
  fi

  log "Downloading $destination"
  curl -fsSL "$url" -o "$destination"
}

install_oh_my_zsh() {
  if [[ -d "$OH_MY_ZSH_DIR" ]]; then
    log "Oh My Zsh already installed at $OH_MY_ZSH_DIR"
    return
  fi

  log "Installing Oh My Zsh"
  RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh -c \
    "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
}

update_tmux_conf() {
  local marker="# 250714 Update .tmux.conf"
  local target="$HOME/.tmux.conf"

  mkdir -p "$(dirname "$target")"
  touch "$target"

  if grep -Fq "$marker" "$target"; then
    log "tmux config already updated"
    return
  fi

  {
    printf '\n%s\n' "$marker"
    curl -fsSL https://raw.githubusercontent.com/xk-huang/dotfiles/main/tmux/.tmux.conf
  } >> "$target"
  log "Updated $target"
}

configure_zshrc() {
  local zshrc="$HOME/.zshrc"

  if [[ ! -f "$zshrc" ]]; then
    log "Expected $zshrc to exist after Oh My Zsh install"
    exit 1
  fi

  cp "$zshrc" "$zshrc.$(date +'%y%m%d-%H%M%S').bak"

  sed -i.bak 's|^ZSH_THEME=.*|ZSH_THEME="powerlevel10k/powerlevel10k"|' "$zshrc"
  sed -i.bak 's/^plugins=(.*)/plugins=(git zsh-autosuggestions zsh-syntax-highlighting alias-tips aliases history tmux)/' "$zshrc"

  append_if_missing "$zshrc" "# 240407 Update .zshrc" "$(cat <<'EOF'
# 240407 Update .zshrc
########################
alias a3='conda activate'
alias c3='conda'
alias sc='source'

export VISUAL=vim
export EDITOR="$VISUAL"

export PATH="$PATH:$HOME/.local/bin"
export PATH="$PATH:$HOME/local/usr/bin"

export PATH="$PATH:$HOME/conda-usr/bin"

export PATH="$PATH:/usr/local/cuda/bin"
export LD_LIBRARY_PATH="${LD_LIBRARY_PATH:+$LD_LIBRARY_PATH:}/usr/local/cuda/lib64"

# To customize prompt, run "p10k configure" or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

load_dotenv() {
    if [[ -f "$1" ]]; then
        printf 'Found dotenv file at %s\nLoading environment variables from it.\n' "$1"
        set -a
        source "$1"
        set +a
    else
        printf 'No dotenv file found at: %s\n' "$1"
    fi
}
alias lde='load_dotenv'

if [[ -f .env ]]; then
    load_dotenv .env
fi
########################
EOF
)"

  append_if_missing "$zshrc" "# 250407 setup_env_shell extras" "$(cat <<'EOF'
# 250407 setup_env_shell extras
########################
if command -v zoxide >/dev/null 2>&1; then
    eval "$(zoxide init zsh)"
fi

if command -v fzf >/dev/null 2>&1; then
    eval "$(fzf --zsh)"
fi

if command -v eza >/dev/null 2>&1; then
    alias ls='eza'
    alias ll='eza -l --git'
    alias la='eza -la --git'
    alias tree='eza --tree'
fi

if command -v fd >/dev/null 2>&1; then
    alias f='fd'
    alias ff='fd | fzf'
fi
########################
EOF
)"
}

install_shell_plugins() {
  mkdir -p "$ZSH_CUSTOM_DIR/themes" "$ZSH_CUSTOM_DIR/plugins"

  clone_or_update_repo \
    https://github.com/romkatv/powerlevel10k.git \
    "$ZSH_CUSTOM_DIR/themes/powerlevel10k"
  clone_or_update_repo \
    https://github.com/zsh-users/zsh-autosuggestions \
    "$ZSH_CUSTOM_DIR/plugins/zsh-autosuggestions"
  clone_or_update_repo \
    https://github.com/zsh-users/zsh-syntax-highlighting.git \
    "$ZSH_CUSTOM_DIR/plugins/zsh-syntax-highlighting"
  clone_or_update_repo \
    https://github.com/djui/alias-tips.git \
    "$ZSH_CUSTOM_DIR/plugins/alias-tips"
}

setup_dotfiles_repo() {
  clone_or_update_repo https://github.com/xk-huang/dotfiles.git "$DOTFILES_DIR"

  if [[ ! -d "$HOME/.config/nvim" ]]; then
    mkdir -p "$HOME/.config"
    cp -r "$DOTFILES_DIR/nvim" "$HOME/.config/"
    log "Installed Neovim config into $HOME/.config/nvim"
  fi
}

main() {
  require_cmd git
  require_cmd curl

  bash "$SCRIPT_DIR/setup_env_tools.sh"

  install_oh_my_zsh
  install_shell_plugins
  update_tmux_conf
  download_if_missing https://raw.githubusercontent.com/xk-huang/dotfiles/main/git/.gitconfig "$HOME/.gitconfig"
  download_if_missing https://raw.githubusercontent.com/xk-huang/dotfiles/main/p10k/.p10k.zsh "$HOME/.p10k.zsh"
  setup_dotfiles_repo

  if [[ -n "${ONLY_DOWNLOAD:-}" ]]; then
    log "ONLY_DOWNLOAD is set; skipping shell rc modifications"
    exit 0
  fi

  configure_zshrc
  log "Shell environment setup complete"
}

main "$@"
