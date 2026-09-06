#!/usr/bin/env bats
# Apply tier: run chezmoi's real apply engine against an isolated HOME and
# assert the dotfile tree is materialised correctly.
#
# Scripts and externals are excluded: the scripts install Homebrew and GUI
# casks / flatpaks / rpm-ostree layers that cannot succeed headlessly, and
# externals clone from GitHub (slow and flaky). Everything else — templated
# files, directory creation, .chezmoiignore exclusions — is applied for real,
# which is what distinguishes this tier from the render tests.
#
# Run via `make test-apply`; not part of the default suite.

load '../helpers/common'

setup() {
  chez_init ci
  chez apply --exclude=scripts,externals
}

@test "apply: creates the zsh bootstrap config" {
  [ -f "${CHEZ_HOME}/.config/zsh/bootstrap.zshrc" ]
}

@test "apply: creates the generated Brewfile" {
  [ -f "${CHEZ_HOME}/.config/brew/Brewfile" ]
}

@test "apply: creates the herdr config" {
  [ -f "${CHEZ_HOME}/.config/herdr/config.toml" ]
}

@test "apply: does not write the ignored .zsh_plugins.zsh cache" {
  [ ! -e "${CHEZ_HOME}/.config/zsh/.zsh_plugins.zsh" ]
}
