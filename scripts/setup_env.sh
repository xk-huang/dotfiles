#! /bin/bash

# Check if zsh is installed
if ! command -v zsh &> /dev/null; then
    # If not installed, install zsh using apt-get
    if ! command -v sudo; then
        apt-get update
        apt-get install -y zsh
    else
        sudo apt-get update
        sudo apt-get install -y zsh
    fi
else
    echo "zsh is already installed"
fi

# Install git-delta via conda
# Install git-delta for better diff
# Install older version. See https://github.com/xk-huang/dotfiles/blob/main/git/.gitconfig
# if [[ -z "$SKIP_DELTA" ]] && ! command -v delta; then
#     curl -L -o /tmp/git-delta-musl_0.15.1_amd64.deb https://github.com/dandavison/delta/releases/download/0.15.1/git-delta-musl_0.15.1_amd64.deb
#     if ! command -v sudo; then
#         dpkg -i /tmp/git-delta-musl_0.15.1_amd64.deb
#     else
#         sudo dpkg -i /tmp/git-delta-musl_0.15.1_amd64.deb
#     fi
#     rm /tmp/git-delta-musl_0.15.1_amd64.deb
# fi

# Download oh-my-zsh
yes | sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

# Download p10k and other plugins
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k
git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
git clone --depth=1 https://github.com/djui/alias-tips.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/alias-tips

# Install delta-pager
wget https://github.com/dandavison/delta/releases/download/0.18.2/git-delta_0.18.2_amd64.deb
dpkg-deb -x git-delta_0.18.2_amd64.deb ~/local
rm git-delta_0.18.2_amd64.deb

# Download .tmux.conf
# if [[ ! -f ~/.tmux.conf ]]; then
search_string="# 250714 Update .tmux.conf"
if ! grep -q "$search_string" ~/.tmux.conf; then
cat >> ~/.tmux.conf << EOF
# 250714 Update .tmux.conf
EOF
curl -L https://raw.githubusercontent.com/xk-huang/dotfiles/main/tmux/.tmux.conf -o - >> ~/.tmux.conf
fi

# Download .gitconfig
if [[ ! -f ~/.gitconfig ]]; then
    curl -L https://raw.githubusercontent.com/xk-huang/dotfiles/main/git/.gitconfig -o - >> ~/.gitconfig
fi

# Download .p10k.zsh
if [[ ! -f ~/.p10k.zsh ]]; then
    curl -L https://raw.githubusercontent.com/xk-huang/dotfiles/main/p10k/.p10k.zsh -o - >> ~/.p10k.zsh
fi

git clone https://github.com/xk-huang/dotfiles.git ~/dotfiles

if [[ ! -d ~/.config/nvim ]]; then
    mkdir -p ~/.config/
    cp -r ~/dotfiles/nvim ~/.config/
fi

if [[ -n "$ONLY_DOWNLOAD" ]]; then
    echo "Only download, not install"
    exit 0
fi

# Replace them to p10k
cp ~/.zshrc ~/.zshrc."$(date +"%y%m%d-%H%M%S")".bak
sed -i 's/^ZSH_THEME=.*/ZSH_THEME="powerlevel10k\/powerlevel10k"/' ~/.zshrc

# Replace plugins=(git) to my custom plugins
sed -i.bak 's/^plugins=(\(.*\))/plugins=(git zsh-autosuggestions zsh-syntax-highlighting z alias-tips aliases history tmux)/' ~/.zshrc

# Add custom config for .zshrc. Mind the escaped $ and `.
search_string="# 240407 Update .zshrc"
if ! grep -q "$search_string" ~/.zshrc; then
cat >> ~/.zshrc << EOF
# 240407 Update .zshrc
########################
alias a3='conda activate'
alias c3='conda'
alias sc='source'
alias gs='gpustat'

export VISUAL=vim
export EDITOR="\$VISUAL"
export PATH="\$PATH:\$HOME/.local/bin"
export PATH="\$PATH:\$HOME/local/usr/bin"

# export PATH=/usr/local/cuda/bin/:\$PATH  # to compile cuda ext
# To customize prompt, run "p10k configure" or edit ~/.p10k.zsh.

[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# load dotenv file
function load_dotenv() {
    if [[ -f \$1 ]]; then
        echo "Found dotenv file at \$1.\nLoading environment variables from it."
        set -a
        source \$1
        set +a
    else
        echo "No dotenv file found at: \$1"
    fi
}
alias lde="load_dotenv"

if [[ -f .env ]]; then
    load_dotenv .env
else
    echo "No dotenv file found."
fi
########################
EOF
fi

# Change .bash_profile, change default shell to zsh without root permit
# https://unix.stackexchange.com/questions/136423/making-zsh-default-shell-without-root-access

# Remove. It will cause `bash -lc pwd` prints no outputs, which annoys codex.
# [[ ! -f ~/.bash_profile ]] || cp ~/.bash_profile ~/.bash_profile."$(date +"%y%m%d-%H%M%S")".bak
# search_string="# 240407 Update .bash_profile"
# if [[ ! -f ~/.bash_profile ]] || ! grep -q "$search_string" ~/.bash_profile; then
# cat >> ~/.bash_profile <<EOF
# # 240407 Update .bash_profile
# ###############################
# export SHELL=$(which zsh)
# exec $(which zsh) -l
# ###############################
# EOF
# fi

# Add CUDA to PATH
search_string="# 241028 Update .zshrc: add CUDA to PATH"
if ! grep -q "$search_string" ~/.zshrc; then
cat >> ~/.zshrc << EOF
# 241028 Update .zshrc: add CUDA to PATH
########################
export PATH=\$PATH:/usr/local/cuda/bin
export LD_LIBRARY_PATH=\${LD_LIBRARY_PATH:+\$LD_LIBRARY_PATH:}/usr/local/cuda/lib64
########################
EOF
fi
