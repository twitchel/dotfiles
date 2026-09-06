#!/usr/bin/env bats
# Apply-tier smoke tests: run chezmoi's real apply engine against an isolated
# HOME and assert the dotfile tree is materialised correctly.
#
# Scripts and externals are excluded: the after-scripts install Homebrew and GUI
# casks / flatpaks / rpm-ostree layers that cannot succeed in a headless
# container, and externals clone from GitHub (slow/flaky). Everything else — the
# templated files, directory creation, and .chezmoiignore exclusions — is
# applied for real, which is what distinguishes this tier from the render tests.
#
# Run via `make test-apply` (as the non-root `tester` user).

load helpers/common

setup() {
  chez_init ci
  chez apply --exclude=scripts,externals
}

@test "apply: exits 0 and creates the zsh bootstrap config" {
  assert [ -f "${CHEZ_HOME}/.config/zsh/bootstrap.zshrc" ]
}

@test "apply: creates the generated Brewfile" {
  assert [ -f "${CHEZ_HOME}/.config/brew/Brewfile" ]
}

@test "apply: creates the herdr config" {
  assert [ -f "${CHEZ_HOME}/.config/herdr/config.toml" ]
}

@test "apply: does not write the ignored .zsh_plugins.zsh cache" {
  assert [ ! -e "${CHEZ_HOME}/.config/zsh/.zsh_plugins.zsh" ]
}
