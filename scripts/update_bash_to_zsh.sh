#!/usr/bin/env bash

set -euo pipefail

log() {
  printf '[update_bash_to_zsh] %s\n' "$*"
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
  local bashrc="$HOME/.bashrc"
  local block

  block="$(printf '%s\n' \
    '# 260502 switch bash to zsh' \
    '########################' \
    'if [[ $- == *i* ]] \' \
    '   && [ -t 0 ] \' \
    '   && [ -t 1 ] \' \
    '   && command -v zsh >/dev/null 2>&1 \' \
    '   && [ -z "${ZSH_VERSION:-}" ]; then' \
    '    exec zsh' \
    'fi' \
    '########################')"

  upsert_managed_block "$bashrc" "# 260502 switch bash to zsh" "$block"
}

main() {
  require_cmd zsh

  local zsh_path
  zsh_path="$(command -v zsh)"

  if ! try_chsh_to_zsh "$zsh_path"; then
    configure_bashrc_fallback
  fi

  log "Bash to zsh update complete"
}

main "$@"
