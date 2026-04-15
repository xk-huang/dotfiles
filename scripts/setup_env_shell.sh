#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dotfiles}"
OH_MY_ZSH_DIR="${ZSH:-$HOME/.oh-my-zsh}"
ZSH_CUSTOM_DIR="${ZSH_CUSTOM:-$OH_MY_ZSH_DIR/custom}"
# TOOLS_ENV_DIR="${TOOLS_ENV_DIR:-$HOME/conda-usr}"
NVM_DIR="${NVM_DIR:-$HOME/.nvm}"

log() {
  printf '[setup_env_shell] %s\n' "$*"
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    log "Missing required command: $1"
    exit 1
  fi
}

upsert_managed_block() {
  local target_file="$1"
  local marker="$2"
  local block="$3"
  local temp_file

  temp_file="$(mktemp)"

  mkdir -p "$(dirname "$target_file")"
  touch "$target_file"

  if grep -Fq "$marker" "$target_file"; then
    awk -v marker="$marker" -v block="$block" '
      BEGIN {
        block_printed = 0
        replacing = 0
        hashes_seen = 0
      }
      $0 == marker {
        if (!block_printed) {
          print block
          block_printed = 1
        }
        replacing = 1
        hashes_seen = 0
        next
      }
      replacing {
        if ($0 == "########################") {
          hashes_seen++
          if (hashes_seen == 2) {
            replacing = 0
          }
        }
        next
      }
      { print }
      END {
        if (!block_printed) {
          if (NR > 0) {
            print ""
          }
          print block
        }
      }
    ' "$target_file" > "$temp_file"
    mv "$temp_file" "$target_file"
    log "Updated $target_file"
    return
  fi

  cat "$target_file" > "$temp_file"
  printf '\n%s\n' "$block" >> "$temp_file"
  mv "$temp_file" "$target_file"
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
  # if ~/.zshrc already exists, we back it up to ~/.zshrc.pre-oh-my-zsh 
  # to avoid 141 exit code due to pipe failure with "yes |"
  if [[ -f "$HOME/.zshrc" ]]; then
    mv "$HOME/.zshrc" "$HOME/.zshrc.pre-oh-my-zsh.$(date +'%y%m%d-%H%M%S').bak"
    log "Manually backed up existing ~/.zshrc to ~/.zshrc.pre-oh-my-zsh.$(date +'%y%m%d-%H%M%S').bak"
  else
    log "No existing ~/.zshrc found, skipping backup"
  fi

  RUNZSH=no CHSH=no KEEP_ZSHRC=no sh -c \
    "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
  log "Installed Oh My Zsh into $OH_MY_ZSH_DIR"
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

  upsert_managed_block "$zshrc" "# 240407 Update .zshrc" "$(cat <<'EOF'
# 240407 Update .zshrc
########################
alias a3='conda activate'
alias c3='conda'
alias sc='source'

export VISUAL=vim
export EDITOR="$VISUAL"

export PATH="${PATH:+$PATH:}$HOME/.local/bin"
export PATH="${PATH:+$PATH:}$HOME/local/usr/bin"

export PATH="${PATH:+$PATH:}$HOME/conda-usr/bin"

export PATH="${PATH:+$PATH:}/usr/local/cuda/bin"
export LD_LIBRARY_PATH="${LD_LIBRARY_PATH:+$LD_LIBRARY_PATH:}/usr/local/cuda/lib64:/$HOME/conda-usr/lib"

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

  upsert_managed_block "$zshrc" "# 250407 setup_env_shell extras" "$(cat <<'EOF'
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

  upsert_managed_block "$zshrc" "# 260413 nvm setup" "$(cat <<'EOF'
# 260413 nvm setup
########################
export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"

if [[ -s "$NVM_DIR/nvm.sh" ]]; then
    source "$NVM_DIR/nvm.sh"
fi

if [[ -s "$NVM_DIR/bash_completion" ]]; then
    source "$NVM_DIR/bash_completion"
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

  # if SKIP_TOOLS_INSTALL is set, we assume the user has already installed the tools and just want to set up the shell config
  if [[ -z "${SKIP_TOOLS_INSTALL:-}" ]]; then
    if [[ -f "$SCRIPT_DIR/setup_env_tools.sh" ]]; then
        bash "$SCRIPT_DIR/setup_env_tools.sh"
    else
        bash <(curl -fsSL https://raw.githubusercontent.com/xk-huang/dotfiles/main/scripts/setup_env_tools.sh)
    fi
  fi

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
