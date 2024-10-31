#! /bin/bash

if [[ ! -d ~/dotfiles ]]; then
    git clone git@github.com:xk-huang/dotfiles.git ~/dotfiles
fi
cd ~/dotfiles
git pull --rebase --abort-on-conflict
cd -

if [[ ! -d ~/.config/nvim ]]; then
    mkdir -p ~/.config/
    cp -r ~/dotfiles/nvim ~/.config/
else
    rm -rf ~/.config/nvim
fi
cp -r ~/dotfiles/nvim ~/.config/


