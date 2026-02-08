#!/usr/bin/env bash

# Install Chezmoi and apply the dotfiles
mkdir -p $HOME/.local/bin
export PATH="$HOME/.local/bin:$PATH"
sh -c "$(curl -fsLS get.chezmoi.io)" -- -b $HOME/.local/bin

# Apply the dotfiles
chezmoi init --source "$(pwd)" --no-tty          
chezmoi apply --source "$(pwd)" --no-tty