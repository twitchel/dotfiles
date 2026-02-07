#!/usr/bin/env bash

# Install Chezmoi and apply the dotfiles
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply --source-path $(pwd)