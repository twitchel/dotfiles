#!/bin/sh

# Exit if zsh is already installed
if command -v zsh >/dev/null 2>&1; then
  exit 0
fi

# Install zsh based on the OS
if [ "$(uname)" = "Darwin" ]; then
  # macOS
  if command -v brew >/dev/null 2>&1; then
    echo "Installing zsh with Homebrew..."
    brew install zsh
  else
    echo "Homebrew not found. Please install Homebrew to automatically install zsh."
    exit 1
  fi
elif [ "$(uname)" = "Linux" ]; then
  # Linux
  if command -v apt-get >/dev/null 2>&1; then
    echo "Installing zsh with apt-get..."
    sudo apt-get update
    sudo apt-get install -y zsh
  elif command -v dnf >/dev/null 2>&1; then
    echo "Installing zsh with dnf..."
    sudo dnf install -y zsh
  elif command -v yum >/dev/null 2>&1; then
    echo "Installing zsh with yum..."
    sudo yum install -y zsh
  elif command -v pacman >/dev/null 2>&1; then
    echo "Installing zsh with pacman..."
    sudo pacman -S --noconfirm zsh
  else
    echo "Could not find a supported package manager (apt-get, dnf, yum, pacman). Please install zsh manually."
    exit 1
  fi
else
  echo "Unsupported OS: $(uname). Please install zsh manually."
  exit 1
fi
