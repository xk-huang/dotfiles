#!/bin/bash
set -euo pipefail

function usage() {
  echo "Usage: $0 <host_user_name> <host_user_uid> <host_user_gid>"
  exit 1
}

if [ "$#" -ne 3 ]; then
  usage
fi

user_name="$1"
user_uid="$2"
user_gid="$3"

pkg_manager=""
if command -v apt-get >/dev/null 2>&1; then
  pkg_manager="apt-get"
elif command -v dnf >/dev/null 2>&1; then
  pkg_manager="dnf"
elif command -v yum >/dev/null 2>&1; then
  pkg_manager="yum"
fi

install_packages() {
  if [ "$#" -eq 0 ]; then
    return 0
  fi
  if [ -z "$pkg_manager" ]; then
    echo "missing packages: $*; no supported package manager was found" >&2
    exit 1
  fi
  if [ "$pkg_manager" = "apt-get" ]; then
    export DEBIAN_FRONTEND=noninteractive
    apt-get update
    apt-get install -y "$@"
  else
    "$pkg_manager" install -y "$@"
  fi
}

if ! command -v sudo >/dev/null 2>&1; then
  install_packages sudo
fi

missing_tools=()
for tool in zsh tmux ffmpeg; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    missing_tools+=("$tool")
  fi
done
if [ "${#missing_tools[@]}" -gt 0 ]; then
  install_packages "${missing_tools[@]}"
fi

if ! command -v groupadd >/dev/null 2>&1 || ! command -v useradd >/dev/null 2>&1; then
  echo "groupadd and useradd are required in the container" >&2
  exit 1
fi

group_name="$(getent group "$user_gid" | cut -d: -f1 || true)"
if [ -z "$group_name" ]; then
  if getent group "$user_name" >/dev/null 2>&1; then
    echo "group $user_name already exists with gid $(getent group "$user_name" | cut -d: -f3), expected $user_gid" >&2
    exit 1
  fi
  groupadd -g "$user_gid" "$user_name"
  group_name="$user_name"
fi

if getent passwd "$user_name" >/dev/null 2>&1; then
  if [ "$(id -u "$user_name")" != "$user_uid" ]; then
    echo "user $user_name already exists with uid $(id -u "$user_name"), expected $user_uid" >&2
    exit 1
  fi
  if [ "$(id -g "$user_name")" != "$user_gid" ]; then
    echo "user $user_name already exists with gid $(id -g "$user_name"), expected $user_gid" >&2
    exit 1
  fi
else
  uid_owner="$(getent passwd "$user_uid" | cut -d: -f1 || true)"
  if [ -n "$uid_owner" ]; then
    echo "uid $user_uid is already owned by $uid_owner" >&2
    exit 1
  fi
  useradd -m -u "$user_uid" -g "$group_name" -s /bin/bash "$user_name"
fi

home_dir="$(getent passwd "$user_name" | cut -d: -f6)"
if [ -z "$home_dir" ]; then
  home_dir="/home/$user_name"
fi
mkdir -p "$home_dir"
chown "$user_uid:$user_gid" "$home_dir"

install -d -m 0755 /etc/sudoers.d
printf "%s ALL=(ALL) NOPASSWD:ALL\n" "$user_name" > "/etc/sudoers.d/90-$user_name"
chmod 0440 "/etc/sudoers.d/90-$user_name"

exec sudo -u "$user_name" -i