#!/usr/bin/env bats
# Rendering tests for the generated Brewfile and per-host package merging.

load helpers/common

@test "ci host: Brewfile has host-specific and common brew packages" {
  chez_init ci
  run chez_cat .config/brew/Brewfile
  assert_success
  assert_line 'brew "hello"'   # ci host-specific
  assert_line 'brew "act"'     # default/common
}

@test "coffee-sponge: casks render on Linux (cask-on-linux)" {
  chez_init coffee-sponge
  run chez_cat .config/brew/Brewfile
  assert_success
  assert_line 'cask "1password-gui-linux"'
  assert_line 'cask "claude-code"'
}

@test "coffee-sponge: common flatpaks render on a Linux host" {
  chez_init coffee-sponge
  run chez_cat .config/brew/Brewfile
  assert_success
  assert_line 'flatpak "com.brave.Browser"'
}

@test "grease-monkey: host brew package merges with common packages" {
  chez_init grease-monkey
  run chez_cat .config/brew/Brewfile
  assert_success
  assert_line 'brew "tailscale"'  # host-specific
  assert_line 'brew "starship"'   # common
}

@test "hostname is normalised to lowercase" {
  chez_init Coffee-Sponge
  run chez data
  assert_success
  assert_output --partial '"hostname": "coffee-sponge"'
}

@test "a host with no extra packages still renders the common block" {
  # grease-monkey has an empty flatpak list and only one extra brew; the
  # template must not error and must still emit the common packages.
  chez_init grease-monkey
  run chez_cat .config/brew/Brewfile
  assert_success
  assert_line 'brew "neovim"'
}
