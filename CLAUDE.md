# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A [chezmoi](https://www.chezmoi.io/) dotfiles repo for managing shell configuration, packages, and tooling across macOS (Tahoe) and Fedora (Workstation and Silverblue). The chezmoi source root is the `home/` directory (set via `.chezmoiroot`).

## Key commands

```bash
# Apply dotfiles to the current machine
chezmoi apply -S .

# Preview what would change without applying
chezmoi diff -S .

# Initialize chezmoi config (prompts for hostname, email)
chezmoi init -S .

# Re-run init prompts (e.g. to change hostname)
chezmoi init --prompt -S .

# View resolved template data
chezmoi data -S .

# Run CI locally against the repo
# (mirrors what GitHub Actions does)
chezmoi apply -S . --no-tty
```

## Architecture

### Template data flow

Machine-specific config comes from two sources:
- `home/.chezmoi.yaml.tmpl` — detects OS (`osid`), prompts for `customHostname`/`email`, sets `BREWPATH`/`BREWBIN`, normalises hostname to lowercase
- `home/.chezmoidata.yaml` — package/host data; two-level structure: `hostData.default` (all machines) merged with `hostData.<hostname>` (machine-specific overrides)

Templates reference this data as `.hostData.default`, `.hostData.<hostname>`, `.hostname`, `.email`, etc.

### Package management

Packages are managed through Homebrew on both macOS and Linux (via Linuxbrew). The Brewfile at `home/dot_config/brew/Brewfile.tmpl` is generated from three partial templates:
- `home/.chezmoitemplates/brew/base.brew.tmpl` — CLI tools (all machines)
- `home/.chezmoitemplates/brew/cask.brew.tmpl` — macOS GUI apps
- `home/.chezmoitemplates/brew/flatpak.brew.tmpl` — Linux GUI apps via Flatpak

To add a package: add it under the appropriate key in `home/.chezmoidata.yaml` (`hostData.default.packages.brew`, `hostData.default.packages.flatpak`, or a host-specific block under `hostData.<hostname>`). `packages.json` is a reference catalog only and is not used by chezmoi scripts.

### Script execution order

chezmoi runs scripts in lexicographic order within each phase:
- **before/**: `010_install-homebrew` — installs Homebrew if missing
- **after/**: `010_install-brew-packages` → `900_set-default-shell` → `999_post-run`

Scripts use the `onchange_` prefix to re-run only when their content changes (hashed by chezmoi).

### External sources

`home/.chezmoiexternal.toml` pulls in:
- `.config/nvim` — LazyVim starter kit (git-repo)
- `.config/tmux/plugins/catppuccin` — Catppuccin tmux theme (archive, pinned to v2.1.3)

### ZSH configuration

The ZSH setup is split across files sourced in order:
1. `home/dot_zshrc` — sets `ZDOTDIR` to `~/.config/zsh`
2. `home/dot_config/zsh/dot_zshrc` — main entry, sources the files below
3. `home/dot_config/zsh/bootstrap.zshrc.tmpl` — Homebrew PATH, Antidote plugin manager, Starship, atuin, NVM, zoxide
4. `home/dot_config/zsh/aliases.zshrc` — shell aliases
5. `home/dot_config/zsh/dot_zsh_plugins.txt` — Antidote plugin list (zsh-autosuggestions, zsh-completions, zsh-syntax-highlighting, zpm-zsh/clipboard)

The generated `.config/zsh/.zsh_plugins.zsh` is excluded via `.chezmoiignore`.

## CI

GitHub Actions (`.github/workflows/pull-request.yaml`) runs `chezmoi init -S . && chezmoi apply -S .` in containers for `fedora:43`, `ubuntu:25.10`, and `macos-latest`. CI sets `CI=true` to bypass interactive prompts, using `ci` as the hostname and `ci@example.com` as the email.
