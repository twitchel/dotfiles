#!/usr/bin/env bash

# Install Chezmoi and apply the dotfiles
sh -c "$(curl -fsLS get.chezmoi.io)" -- -b $HOME/.local/bin

# Apply the dotfiles
chezmoi init --apply --source "$(pwd)" --no-tty