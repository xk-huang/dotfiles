# Setup Scripts

These scripts install a shell-focused development environment and configure zsh,
tmux, git, Neovim, conda tools, nvm, Node.js, and Codex CLI.

## Common Usage

Install everything into the current home directory:

```bash
bash scripts/setup_env_shell.sh
```

Install tools/configs into a persistent home-like directory while keeping the
real login `$HOME` mostly empty:

```bash
SETUP_HOME=/mnt/nfs/$USER bash scripts/setup_env_shell.sh
```

In persistent-home mode, the real configs are written under `SETUP_HOME`.
Minimal bootstrap files are written under the actual `$HOME` so login shells and
tmux can find the persistent config:

- `$HOME/.zshenv` sets `ZDOTDIR=$SETUP_HOME`.
- `$HOME/.bashrc` can exec zsh for interactive bash sessions.
- `$HOME/.tmux.conf` sources `$SETUP_HOME/.tmux.conf`.

## Scripts

### `setup_env_shell.sh`

Main entrypoint. It runs `setup_env_tools.sh` unless `SKIP_TOOLS_INSTALL` is set,
then installs/configures:

- Miniconda tool environment.
- Oh My Zsh and zsh plugins.
- tmux config.
- git config.
- Powerlevel10k config.
- Neovim config.
- zsh rc blocks for conda, nvm, aliases, and helper tools.

Useful variables:

| Variable | Default | Purpose |
| --- | --- | --- |
| `SETUP_HOME` | `$HOME` | Persistent home-like root for configs and user tools. |
| `BOOTSTRAP_HOME` | `$HOME` | Home directory where shell-discovered bootstrap files are written. |
| `BASE_DIR` | `$SETUP_HOME` | Root for Miniconda and the conda tools env. |
| `MINICONDA_DIR` | `$BASE_DIR/miniconda3` | Miniconda install path. |
| `TOOLS_ENV_DIR` | `$BASE_DIR/conda-usr` | Conda environment for CLI tools. |
| `DOTFILES_DIR` | `$SETUP_HOME/dotfiles` | Dotfiles repo clone/update location. |
| `NVM_DIR` | `$SETUP_HOME/.nvm` | nvm install path. |
| `XDG_CONFIG_HOME` | `$SETUP_HOME/.config` | XDG config root, including Neovim config. |
| `GIT_CONFIG_GLOBAL` | `$SETUP_HOME/.gitconfig` | Global git config path exported by shell setup. |
| `ONLY_DOWNLOAD` | unset | If set, skip shell rc/bootstrap modifications. |
| `SKIP_TOOLS_INSTALL` | unset | If set, skip running `setup_env_tools.sh`. |

Examples:

```bash
# Persistent install for an ephemeral login home.
SETUP_HOME=/mnt/nfs/$USER bash scripts/setup_env_shell.sh

# Configure shell files only after tools were installed separately.
SETUP_HOME=/mnt/nfs/$USER SKIP_TOOLS_INSTALL=1 bash scripts/setup_env_shell.sh

# Download/install assets but do not touch rc files.
SETUP_HOME=/mnt/nfs/$USER ONLY_DOWNLOAD=1 bash scripts/setup_env_shell.sh
```

## Resume on a New Machine

If you already installed into a persistent path such as `/mnt/nfs/$USER` and then
log into a new machine with a fresh ephemeral `$HOME`, the persistent install is
still present but the new `$HOME` is missing bootstrap files.

Recreate the bootstrap files without reinstalling tools:

```bash
SETUP_HOME=/mnt/nfs/$USER SKIP_TOOLS_INSTALL=1 bash /mnt/nfs/$USER/dotfiles/scripts/setup_env_shell.sh
```

Then start a fresh zsh session:

```bash
exec zsh
```

To make future interactive bash logins switch to zsh automatically on this
machine, run:

```bash
SETUP_HOME=/mnt/nfs/$USER bash /mnt/nfs/$USER/dotfiles/scripts/update_bash_to_zsh.sh
```

`update_bash_to_zsh.sh` prefers the zsh installed in the persistent conda tools
environment at `$TOOLS_ENV_DIR/bin/zsh`, then falls back to `command -v zsh`.
If `chsh` cannot set that shell as the login shell, it writes a managed `.bashrc`
fallback that execs the resolved zsh path.

You can also start the persistent conda zsh directly:

```bash
/mnt/nfs/$USER/conda-usr/bin/zsh
```

Notes:

- The persistent path should be the same as the original install path.
- The installed conda/tools environment must be compatible with the new machine.
  Same Linux architecture is usually fine; different OS or CPU architecture is
  not expected to work.
- `SKIP_TOOLS_INSTALL=1` keeps the resume step lightweight and only refreshes the
  shell/bootstrap configuration.
- If your zsh lives somewhere else, pass `ZSH_PATH=/path/to/zsh` when running
  `update_bash_to_zsh.sh`.

### `setup_env_tools.sh`

Installs Miniconda, creates the tools conda environment, installs CLI packages,
installs uv, installs nvm/Node.js, and installs Codex CLI.

Useful variables:

| Variable | Default | Purpose |
| --- | --- | --- |
| `SETUP_HOME` | `$HOME` | Persistent home-like root for user tools. |
| `BASE_DIR` | `$SETUP_HOME` | Root for Miniconda and conda env. |
| `MINICONDA_DIR` | `$BASE_DIR/miniconda3` | Miniconda install path. |
| `TOOLS_ENV_DIR` | `$BASE_DIR/conda-usr` | Conda environment for tools. |
| `NVM_DIR` | `$SETUP_HOME/.nvm` | nvm install path. |
| `UV_INSTALL_DIR` | `$SETUP_HOME/.local/bin` | uv install directory. |
| `NODE_VERSION` | `lts/*` | Node.js version passed to nvm. |
| `INSTALLER_DIR` | `/tmp` | Miniconda installer download directory. |

Example:

```bash
SETUP_HOME=/mnt/nfs/$USER bash scripts/setup_env_tools.sh
```

### `update_bash_to_zsh.sh`

Attempts to switch the login shell to zsh with `chsh`. If that cannot complete,
it installs an interactive `.bashrc` fallback that execs zsh.

With `SETUP_HOME` set to a persistent path, it also writes `$HOME/.zshenv` so zsh
loads rc files from the persistent setup directory.

It resolves zsh in this order:

1. `ZSH_PATH`, if set.
2. `$TOOLS_ENV_DIR/bin/zsh`, if executable.
3. `command -v zsh`.

Example:

```bash
SETUP_HOME=/mnt/nfs/$USER bash scripts/update_bash_to_zsh.sh
```

### `open_container_shell_as_host_user.sh`

Starts a container shell as the host user. Use this when you need an interactive
container session that maps user identity and workspace access in the way this
repo expects.

## Notes

- Defaults preserve existing behavior: no variables means install into `$HOME`.
- Persistent-home mode is intended for environments where `$HOME` is ephemeral
  but a path such as `/mnt/nfs/$USER` survives across sessions.
- Re-running the scripts is intended to be safe. Managed rc blocks are updated
  in place instead of appended repeatedly.
