#!/bin/bash

set -e

ZSH_PATH=$(which zsh)

# Add zsh to list of valid shells in /etc/shells
echo $ZSH_PATH | sudo tee -a /etc/shells

# Set default shell to zsh
chsh -s $ZSH_PATH
