# dotfiles

Managed with [chezmoi](https://www.chezmoi.io/)

## Supported Machines

- **grease-monkey** - Fedora Linux Laptop (Personal Use)
- **MAC-4944** - MacOS Tahoe (Work Use)

## Features

- **Automatic Homebrew Installation**: Installs Homebrew on macOS and Linux if not already present
- **Hostname-based Package Management**: Configure different packages per machine via brew
- **Container Support**: Default installation script for Ubuntu-based containers
- **Common Packages**: Packages installed on all machines (e.g., duckdb)

## Requirements

### MacOS

A running system with the following installed:
- git (Homebrew will be installed automatically)

### Ubuntu

A running system with the following installed:
- git
- zsh (installed automatically)

### Manjaro

A running system with the following installed:
- zsh (set as default shell)
- git

### Containers

Ubuntu-based containers will be automatically configured with essential packages.