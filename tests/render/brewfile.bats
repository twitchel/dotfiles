#!/usr/bin/env bats
# Render tier: the generated Brewfile and per-host package merging.
#
# These assert on what chezmoi actually writes, which the unit tier in
# tests/bats does not cover — nothing else checks the Brewfile templates.

load '../helpers/common'

@test "ci host: Brewfile has host-specific and common brew packages" {
  chez_init ci
  run chez_cat .config/brew/Brewfile
  [ "$status" -eq 0 ]
  assert_line_in_output 'brew "hello"' # ci host-specific
  assert_line_in_output 'brew "act"'   # default/common
}

@test "coffee-sponge: casks render on Linux (cask-on-linux)" {
  chez_init coffee-sponge
  run chez_cat .config/brew/Brewfile
  [ "$status" -eq 0 ]
  assert_line_in_output 'cask "1password-gui-linux"'
  assert_line_in_output 'cask "claude-code"'
}

@test "grease-monkey: host brew package merges with common packages" {
  chez_init grease-monkey
  run chez_cat .config/brew/Brewfile
  [ "$status" -eq 0 ]
  assert_line_in_output 'brew "tailscale"' # host-specific
  assert_line_in_output 'brew "starship"'  # common
}

@test "hostname is normalised to lowercase" {
  chez_init Coffee-Sponge
  run chez data
  [ "$status" -eq 0 ]
  [[ "$output" == *'"hostname": "coffee-sponge"'* ]]
}

@test "a host with no extra packages still renders the common block" {
  # grease-monkey has an empty flatpak list and only one extra brew; the
  # template must not error and must still emit the common packages.
  chez_init grease-monkey
  run chez_cat .config/brew/Brewfile
  [ "$status" -eq 0 ]
  assert_line_in_output 'brew "neovim"'
}

@test "an unknown host renders the common block without erroring" {
  chez_init not-a-real-host
  run chez_cat .config/brew/Brewfile
  [ "$status" -eq 0 ]
  assert_line_in_output 'brew "starship"'
}
