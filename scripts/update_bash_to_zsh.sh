#!/usr/bin/env bash

set -euo pipefail

SETUP_HOME="${SETUP_HOME:-$HOME}"
BOOTSTRAP_HOME="${BOOTSTRAP_HOME:-$HOME}"
BASE_DIR="${BASE_DIR:-$SETUP_HOME}"
TOOLS_ENV_DIR="${TOOLS_ENV_DIR:-$BASE_DIR/conda-usr}"

if [[ -z "${XDG_CONFIG_HOME:-}" || ( "$SETUP_HOME" != "$HOME" && "$XDG_CONFIG_HOME" == "$HOME/.config" ) ]]; then
  XDG_CONFIG_HOME="$SETUP_HOME/.config"
fi

if [[ -z "${GIT_CONFIG_GLOBAL:-}" || ( "$SETUP_HOME" != "$HOME" && "$GIT_CONFIG_GLOBAL" == "$HOME/.gitconfig" ) ]]; then
  GIT_CONFIG_GLOBAL="$SETUP_HOME/.gitconfig"
fi

if [[ -z "${NVM_DIR:-}" || ( "$SETUP_HOME" != "$HOME" && "$NVM_DIR" == "$HOME/.nvm" ) ]]; then
  NVM_DIR="$SETUP_HOME/.nvm"
fi

log() {
  printf '[update_bash_to_zsh] %s\n' "$*"
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

  log "Missing required command: zsh"
  exit 1
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

try_chsh_to_zsh() {
  local zsh_path="$1"

  if [[ "${SHELL:-}" == "$zsh_path" ]]; then
    log "Login shell is already $zsh_path"
    return 0
  fi

  if ! command -v chsh >/dev/null 2>&1; then
    log "chsh not found; updating .bashrc fallback"
    return 1
  fi

  log "Trying to change login shell to $zsh_path"
  if chsh -s "$zsh_path" </dev/null; then
    log "Changed login shell to $zsh_path"
    return 0
  fi

  log "chsh did not complete without password/root; updating .bashrc fallback"
  return 1
}

configure_bashrc_fallback() {
  local zsh_path="$1"
  local bashrc="$BOOTSTRAP_HOME/.bashrc"
  local block
  local git_config_q setup_home_q xdg_config_q zsh_path_q

  git_config_q="$(shell_quote "$GIT_CONFIG_GLOBAL")"
  setup_home_q="$(shell_quote "$SETUP_HOME")"
  xdg_config_q="$(shell_quote "$XDG_CONFIG_HOME")"
  zsh_path_q="$(shell_quote "$zsh_path")"

  block="$(cat <<EOF
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

  upsert_managed_block "$bashrc" "# 260502 switch bash to zsh" "$block"
}

configure_zshenv_bootstrap() {
  local zshenv="$BOOTSTRAP_HOME/.zshenv"
  local git_config_q nvm_dir_q setup_home_q xdg_config_q

  if [[ "$SETUP_HOME" == "$BOOTSTRAP_HOME" ]]; then
    return
  fi

  git_config_q="$(shell_quote "$GIT_CONFIG_GLOBAL")"
  nvm_dir_q="$(shell_quote "$NVM_DIR")"
  setup_home_q="$(shell_quote "$SETUP_HOME")"
  xdg_config_q="$(shell_quote "$XDG_CONFIG_HOME")"

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
}

main() {
  local zsh_path
  zsh_path="$(resolve_zsh_path)"

  configure_zshenv_bootstrap

  if ! try_chsh_to_zsh "$zsh_path"; then
    configure_bashrc_fallback "$zsh_path"
  fi

  log "Bash to zsh update complete"
}

main "$@"
