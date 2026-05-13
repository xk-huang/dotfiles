#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SETUP_HOME="${SETUP_HOME:-$HOME}"
BOOTSTRAP_HOME="${BOOTSTRAP_HOME:-$HOME}"
BASE_DIR="${BASE_DIR:-$SETUP_HOME}"
DOTFILES_DIR="${DOTFILES_DIR:-$SETUP_HOME/dotfiles}"
MINICONDA_DIR="${MINICONDA_DIR:-$BASE_DIR/miniconda3}"
TOOLS_ENV_DIR="${TOOLS_ENV_DIR:-$BASE_DIR/conda-usr}"

if [[ -n "${ZSH:-}" && ( "$SETUP_HOME" == "$HOME" || "$ZSH" != "$HOME/.oh-my-zsh" ) ]]; then
  OH_MY_ZSH_DIR="$ZSH"
else
  OH_MY_ZSH_DIR="$SETUP_HOME/.oh-my-zsh"
fi
ZSH_CUSTOM_DIR="${ZSH_CUSTOM:-$OH_MY_ZSH_DIR/custom}"

if [[ -z "${NVM_DIR:-}" || ( "$SETUP_HOME" != "$HOME" && "$NVM_DIR" == "$HOME/.nvm" ) ]]; then
  NVM_DIR="$SETUP_HOME/.nvm"
fi

if [[ -z "${XDG_CONFIG_HOME:-}" || ( "$SETUP_HOME" != "$HOME" && "$XDG_CONFIG_HOME" == "$HOME/.config" ) ]]; then
  XDG_CONFIG_HOME="$SETUP_HOME/.config"
fi

if [[ -z "${GIT_CONFIG_GLOBAL:-}" || ( "$SETUP_HOME" != "$HOME" && "$GIT_CONFIG_GLOBAL" == "$HOME/.gitconfig" ) ]]; then
  GIT_CONFIG_GLOBAL="$SETUP_HOME/.gitconfig"
fi

P10K_FILE="${P10K_FILE:-$SETUP_HOME/.p10k.zsh}"
TMUX_CONF="${TMUX_CONF:-$SETUP_HOME/.tmux.conf}"
NVIM_CONFIG_DIR="${NVIM_CONFIG_DIR:-$XDG_CONFIG_HOME/nvim}"

log() {
  printf '[setup_env_shell] %s\n' "$*"
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    log "Missing required command: $1"
    exit 1
  fi
}

shell_quote() {
  printf '%q' "$1"
}

tmux_quote() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  printf '"%s"' "$value"
}

resolve_zsh_path() {
  if [[ -n "${ZSH_PATH:-}" ]]; then
    printf '%s\n' "$ZSH_PATH"
    return
  fi

  if [[ -x "$TOOLS_ENV_DIR/bin/zsh" ]]; then
    printf '%s\n' "$TOOLS_ENV_DIR/bin/zsh"
    return
  fi

  if command -v zsh >/dev/null 2>&1; then
    command -v zsh
    return
  fi

  printf 'zsh\n'
}

upsert_managed_block() {
  local target_file="$1"
  local marker="$2"
  local block="$3"
  local block_file
  local temp_file

  block_file="$(mktemp)"
  temp_file="$(mktemp)"
  printf '%s\n' "$block" > "$block_file"

  mkdir -p "$(dirname "$target_file")"
  touch "$target_file"

  if grep -Fq "$marker" "$target_file"; then
    awk -v marker="$marker" -v block_file="$block_file" '
      function print_block(  line) {
        while ((getline line < block_file) > 0) {
          print line
        }
        close(block_file)
      }
      BEGIN {
        block_printed = 0
        replacing = 0
        hashes_seen = 0
      }
      $0 == marker {
        if (!block_printed) {
          print_block()
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
          print_block()
        }
      }
    ' "$target_file" > "$temp_file"
    mv "$temp_file" "$target_file"
    rm -f "$block_file"
    log "Updated $target_file"
    return
  fi

  cat "$target_file" > "$temp_file"
  printf '\n%s\n' "$block" >> "$temp_file"
  mv "$temp_file" "$target_file"
  rm -f "$block_file"
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
  mkdir -p "$(dirname "$destination")"
  curl -fsSL "$url" -o "$destination"
}

install_oh_my_zsh() {
  local zshrc="$SETUP_HOME/.zshrc"
  local timestamp

  if [[ -d "$OH_MY_ZSH_DIR" ]]; then
    log "Oh My Zsh already installed at $OH_MY_ZSH_DIR"
    return
  fi

  log "Installing Oh My Zsh"
  mkdir -p "$SETUP_HOME"
  timestamp="$(date +'%y%m%d-%H%M%S')"

  # If .zshrc already exists, back it up before Oh My Zsh replaces it
  # to avoid 141 exit code due to pipe failure with "yes |"
  if [[ -f "$zshrc" ]]; then
    mv "$zshrc" "$zshrc.pre-oh-my-zsh.$timestamp.bak"
    log "Manually backed up existing $zshrc to $zshrc.pre-oh-my-zsh.$timestamp.bak"
  else
    log "No existing $zshrc found, skipping backup"
  fi

  HOME="$SETUP_HOME" ZSH="$OH_MY_ZSH_DIR" RUNZSH=no CHSH=no KEEP_ZSHRC=no sh -c \
    "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
  log "Installed Oh My Zsh into $OH_MY_ZSH_DIR"
}

update_tmux_conf() {
  local marker="# 250714 Update .tmux.conf"
  local target="$TMUX_CONF"

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
  local zshrc="$SETUP_HOME/.zshrc"
  local conda_init_q git_config_q nvm_dir_q oh_my_zsh_q p10k_file_q setup_home_q tools_env_q xdg_config_q

  conda_init_q="$(shell_quote "$MINICONDA_DIR/etc/profile.d/conda.sh")"
  git_config_q="$(shell_quote "$GIT_CONFIG_GLOBAL")"
  nvm_dir_q="$(shell_quote "$NVM_DIR")"
  oh_my_zsh_q="$(shell_quote "$OH_MY_ZSH_DIR")"
  p10k_file_q="$(shell_quote "$P10K_FILE")"
  setup_home_q="$(shell_quote "$SETUP_HOME")"
  tools_env_q="$(shell_quote "$TOOLS_ENV_DIR")"
  xdg_config_q="$(shell_quote "$XDG_CONFIG_HOME")"

  if [[ ! -f "$zshrc" ]]; then
    log "Expected $zshrc to exist after Oh My Zsh install"
    exit 1
  fi

  cp "$zshrc" "$zshrc.$(date +'%y%m%d-%H%M%S').bak"

  sed -i.bak "s|^export ZSH=.*|export ZSH=$oh_my_zsh_q|" "$zshrc"
  sed -i.bak 's|^ZSH_THEME=.*|ZSH_THEME="powerlevel10k/powerlevel10k"|' "$zshrc"
  sed -i.bak 's/^plugins=(.*)/plugins=(git zsh-autosuggestions zsh-syntax-highlighting alias-tips aliases history tmux)/' "$zshrc"

  upsert_managed_block "$zshrc" "# 240407 Update .zshrc" "$(cat <<EOF
# 240407 Update .zshrc
########################
alias a3='conda activate'
alias c3='conda'
alias sc='source'

export SETUP_HOME=$setup_home_q
export XDG_CONFIG_HOME=$xdg_config_q
export GIT_CONFIG_GLOBAL=$git_config_q

export VISUAL=vim
export EDITOR="\$VISUAL"

export PATH="\${PATH:+\$PATH:}\$SETUP_HOME/.local/bin"
export PATH="\${PATH:+\$PATH:}\$SETUP_HOME/local/usr/bin"

export PATH="\${PATH:+\$PATH:}/usr/local/cuda/bin"
export LD_LIBRARY_PATH="\${LD_LIBRARY_PATH:+\$LD_LIBRARY_PATH:}/usr/local/cuda/lib64"

if [[ -f $conda_init_q ]]; then
  source $conda_init_q
  conda activate $tools_env_q
else
  echo "No miniconda initialization found at $conda_init_q; skipping conda initialization"
fi

# To customize prompt, run "p10k configure" or edit $P10K_FILE.
[[ ! -f $p10k_file_q ]] || source $p10k_file_q

load_dotenv() {
    if [[ -f "\$1" ]]; then
        printf 'Found dotenv file at %s\nLoading environment variables from it.\n' "\$1"
        set -a
        source "\$1"
        set +a
    else
        printf 'No dotenv file found at: %s\n' "\$1"
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

  upsert_managed_block "$zshrc" "# 260413 nvm setup" "$(cat <<EOF
# 260413 nvm setup
########################
if [[ -z "\${NVM_DIR:-}" ]]; then
    export NVM_DIR=$nvm_dir_q
else
    export NVM_DIR
fi

if [[ -s "\$NVM_DIR/nvm.sh" ]]; then
    source "\$NVM_DIR/nvm.sh"
fi

if [[ -s "\$NVM_DIR/bash_completion" ]]; then
    source "\$NVM_DIR/bash_completion"
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

  if [[ ! -d "$NVIM_CONFIG_DIR" ]]; then
    mkdir -p "$(dirname "$NVIM_CONFIG_DIR")"
    cp -r "$DOTFILES_DIR/nvim" "$NVIM_CONFIG_DIR"
    log "Installed Neovim config into $NVIM_CONFIG_DIR"
  fi
}

configure_bootstrap_files() {
  local bashrc="$BOOTSTRAP_HOME/.bashrc"
  local tmux_conf="$BOOTSTRAP_HOME/.tmux.conf"
  local zshenv="$BOOTSTRAP_HOME/.zshenv"
  local git_config_q nvm_dir_q setup_home_q tmux_conf_tq xdg_config_q zsh_path zsh_path_q

  if [[ "$SETUP_HOME" == "$BOOTSTRAP_HOME" ]]; then
    return
  fi

  git_config_q="$(shell_quote "$GIT_CONFIG_GLOBAL")"
  nvm_dir_q="$(shell_quote "$NVM_DIR")"
  setup_home_q="$(shell_quote "$SETUP_HOME")"
  tmux_conf_tq="$(tmux_quote "$TMUX_CONF")"
  xdg_config_q="$(shell_quote "$XDG_CONFIG_HOME")"
  zsh_path="$(resolve_zsh_path)"
  zsh_path_q="$(shell_quote "$zsh_path")"

  upsert_managed_block "$zshenv" "# 260513 setup_env_shell bootstrap" "$(cat <<EOF
# 260513 setup_env_shell bootstrap
########################
export SETUP_HOME=$setup_home_q
export ZDOTDIR=\$SETUP_HOME
export XDG_CONFIG_HOME=$xdg_config_q
export GIT_CONFIG_GLOBAL=$git_config_q

if [[ -z "\${NVM_DIR:-}" ]]; then
    export NVM_DIR=$nvm_dir_q
fi
########################
EOF
)"

  upsert_managed_block "$bashrc" "# 260502 switch bash to zsh" "$(cat <<EOF
# 260502 switch bash to zsh
########################
export SETUP_HOME=$setup_home_q
export ZDOTDIR=\$SETUP_HOME
export XDG_CONFIG_HOME=$xdg_config_q
export GIT_CONFIG_GLOBAL=$git_config_q

if [[ \$- == *i* ]] \\
   && [ -t 0 ] \\
   && [ -t 1 ] \\
   && [ -z "\${ZSH_VERSION:-}" ]; then
    if [[ -x $zsh_path_q ]]; then
        exec $zsh_path_q
    elif command -v zsh >/dev/null 2>&1; then
        exec zsh
    fi
fi
########################
EOF
)"

  upsert_managed_block "$tmux_conf" "# 260513 setup_env_shell tmux bootstrap" "$(cat <<EOF
# 260513 setup_env_shell tmux bootstrap
########################
source-file $tmux_conf_tq
########################
EOF
)"
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

main() {
  require_cmd git
  require_cmd curl

  # if SKIP_TOOLS_INSTALL is set, we assume the user has already installed the tools and just want to set up the shell config
  if [[ -z "${SKIP_TOOLS_INSTALL:-}" ]]; then
    if [[ -f "$SCRIPT_DIR/setup_env_tools.sh" ]]; then
        SETUP_HOME="$SETUP_HOME" \
          BASE_DIR="$BASE_DIR" \
          MINICONDA_DIR="$MINICONDA_DIR" \
          TOOLS_ENV_DIR="$TOOLS_ENV_DIR" \
          NVM_DIR="$NVM_DIR" \
          bash "$SCRIPT_DIR/setup_env_tools.sh"
    else
        SETUP_HOME="$SETUP_HOME" \
          BASE_DIR="$BASE_DIR" \
          MINICONDA_DIR="$MINICONDA_DIR" \
          TOOLS_ENV_DIR="$TOOLS_ENV_DIR" \
          NVM_DIR="$NVM_DIR" \
          bash <(curl -fsSL https://raw.githubusercontent.com/xk-huang/dotfiles/main/scripts/setup_env_tools.sh)
    fi
  fi
  
  # Make sure conda-usr is in path and lib path
  init_conda
  ensure_tools_env
  activate_tools_env

  install_oh_my_zsh
  install_shell_plugins
  update_tmux_conf
  download_if_missing https://raw.githubusercontent.com/xk-huang/dotfiles/main/git/.gitconfig "$GIT_CONFIG_GLOBAL"
  download_if_missing https://raw.githubusercontent.com/xk-huang/dotfiles/main/p10k/.p10k.zsh "$P10K_FILE"
  setup_dotfiles_repo

  if [[ -n "${ONLY_DOWNLOAD:-}" ]]; then
    log "ONLY_DOWNLOAD is set; skipping shell rc modifications"
    exit 0
  fi

  configure_zshrc
  configure_bootstrap_files
  log "Shell environment setup complete"
}

main "$@"
