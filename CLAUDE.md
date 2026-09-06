# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A [chezmoi](https://www.chezmoi.io/) dotfiles repo for managing shell configuration, packages, and tooling across macOS (Tahoe), Fedora Silverblue/Workstation/Bazzite, Fedora Server, and Ubuntu. The chezmoi source root is the `home/` directory (set via `.chezmoiroot`).

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
- `home/.chezmoi.yaml.tmpl` — detects OS (`osid`), detects/prompts for `machineType` (`workstation`/`server`), prompts for `customHostname`/`email`, sets `BREWPATH`/`BREWBIN`, normalises hostname to lowercase
- `home/.chezmoidata.yaml` — package/host data; two-level structure: `hostData.default` (all machines) merged with `hostData.<hostname>` (machine-specific overrides)

Templates reference this data as `.hostData.default`, `.hostData.<hostname>`, `.hostname`, `.email`, `.machineType`, etc.

`machineType` is auto-detected from `variantID` in `/etc/os-release`: `silverblue`/`workstation`/`kinoite`/`onyx`/`bazzite` → `workstation`; `server` → `server`; CI → `server`; macOS → always `workstation`. Unknown Linux variants prompt the user.

### Package management

Packages are managed through Homebrew on both macOS and Linux (via Linuxbrew). The Brewfile at `home/dot_config/brew/Brewfile.tmpl` is generated from three partial templates:
- `home/.chezmoitemplates/brew/base.brew.tmpl` — CLI tools (all machines)
- `home/.chezmoitemplates/brew/cask.brew.tmpl` — GUI apps installed via `brew cask` (no longer macOS-only; Linux hosts like `coffee-sponge` use this too, e.g. for `1password-gui-linux`)
- `home/.chezmoitemplates/brew/flatpak.brew.tmpl` — GUI apps via Flatpak (only included when `machineType == "workstation"` AND `flatpak` binary is present)

To add a package: add it under the appropriate key in `home/.chezmoidata.yaml` (`hostData.default.packages.brew`/`brewCask`/`flatpak`, or a host-specific block under `hostData.<hostname>`). `packages.json` is a reference catalog only and is not used by chezmoi scripts.

Other package-related keys under `packages`:
- `brewTaps` / `brewCaskTaps` — tapped (and trusted, for cask taps) before `brew bundle` runs, both at the `default` level and per-host (e.g. `coffee-sponge` taps `ublue-os/tap` for its Linux casks)
- `rpmOstree` — host-specific packages layered onto atomic/immutable Fedora hosts (Silverblue) via `rpm-ostree install`, for things Homebrew can't provide system-wide (e.g. `coffee-sponge` layers `ghostty` and `zsh`)
- `dnf` / `apt` — system packages installed by the `before/` scripts ahead of Homebrew, currently `zsh` and `git`. Keyed per package manager because names diverge between Fedora and Debian. `default` level only for now — these scripts do not read host-specific blocks

### Script execution order

chezmoi runs scripts in lexicographic order within each phase:
- **before/**: `005_dnf-packages` (installs `packages.dnf` via `sudo dnf install`; skips when `dnf` is absent, and skips atomic hosts where `rpm-ostree` is present since `040_rpm-ostree` owns layering there) → `006_apt-packages` (installs `packages.apt`, running `apt-get update` only when something is actually missing) → `010_install-homebrew` — installs Homebrew if missing. Both package scripts filter to not-yet-installed packages first, so a no-op apply never prompts for sudo
- **after/**: `010_silverblue-postinstall` (resets Flatpak remotes to full Flathub on Silverblue) → `040_rpm-ostree` (adds the Ghostty copr repo and layers any `rpmOstree` packages for the host) → `050_install-brew-packages` (taps/trusts `brewTaps`/`brewCaskTaps`, then `brew bundle`s the generated Brewfile — cachebusted via a sha256 hash of `.chezmoidata.yaml` in a comment so it reruns when packages change) → `900_set-default-shell` (picks the first executable shell outside any home directory — brew's prefix first, so macOS keeps `/opt/homebrew/bin/zsh`, then `/usr/bin`, `/bin`, `/usr/local/bin`; then `chsh`, falling back to `sudo usermod -s` on atomic distros. **Never selects a shell under `/home`, `/var/home`, `/Users` or `$HOME`**: sshd cannot exec a `user_home_t`-labelled binary on SELinux distros, so setting Linuxbrew's zsh as the login shell locks you out of SSH entirely) → `999_post-run`

Scripts use the `onchange_` prefix to re-run only when their content changes (hashed by chezmoi).

### External sources

`home/.chezmoiexternal.toml` pulls in:
- `.config/nvim` — LazyVim starter kit (git-repo)
- `.config/tmux/plugins/catppuccin` — Catppuccin tmux theme (archive, pinned to v2.1.3)

### ZSH configuration

The ZSH setup is split across files sourced in order:
1. `home/dot_zshrc` — sets `ZDOTDIR` to `~/.config/zsh`
2. `home/dot_config/zsh/dot_zshrc` — main entry, sources the files below
3. `home/dot_config/zsh/bootstrap.zshrc.tmpl` — SSH agent eval, `~/.local/bin` PATH, Homebrew PATH, Antidote plugin manager, Starship, atuin, NVM, zoxide
4. `home/dot_config/zsh/aliases.zshrc` — shell aliases
5. `home/dot_config/zsh/dot_zsh_plugins.txt` — Antidote plugin list (zsh-autosuggestions, zsh-completions, zsh-syntax-highlighting, zpm-zsh/clipboard)

The generated `.config/zsh/.zsh_plugins.zsh` is excluded via `.chezmoiignore`.

## CI

GitHub Actions (`.github/workflows/pull-request.yaml`) runs `chezmoi init -S . && chezmoi apply -S . && bash tests/run.sh` in containers for `fedora:44`, `ubuntu:26.04`, and `macos-latest`. CI sets `CI=true` to bypass interactive prompts, using `ci` as the hostname and `ci@example.com` as the email. The `apply` step is what installs Homebrew and brew-bundles the Brewfile, which is where `bats` and `yq` come from — without it the test step fails with `Missing: bats`.

## Tests

Three tiers under `tests/` (see `tests/README.md`):

| Tier | Path | What it checks | Default |
|---|---|---|---|
| unit | `tests/bats/` | script bash logic against mocked binaries | yes |
| render | `tests/render/` | what chezmoi actually renders | yes |
| apply | `tests/apply/` | a real `chezmoi apply` into an isolated HOME | no |

`bash tests/run.sh` runs the unit and render tiers and is what CI invokes; it needs `bats`, `yq` and `chezmoi` on PATH. The repo-root `Makefile` reproduces all of it in containers (`make test`, `make ci`, `make test-apply`); `make vendor` fetches bats into the gitignored `tests/vendor/`.

Suites assert in plain bash, not bats-assert, so the only test dependency is bats itself. Helpers live in `tests/helpers/common.bash`: `mock`/`assert_mock_*` for the unit tier, and `chez_init`/`chez_cat`/`chez_template` (which seed an isolated chezmoi config to bypass `promptStringOnce`) for the render tier.

When changing a script, prefer sourcing or rendering the real thing over re-implementing its logic inline in the test — an earlier inline-heredoc suite passed against the code that caused an SSH lockout.
