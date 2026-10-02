#!/usr/bin/env bats
# Render tier: the generated ~/.gitconfig.

load '../helpers/common'

@test ".gitconfig: user.email comes from chezmoi data" {
  chez_init ci someone@example.com
  run chez_cat .gitconfig
  [ "$status" -eq 0 ]
  assert_line_in_output '	email = someone@example.com'
}

@test ".gitconfig: includes the unmanaged ~/.gitconfig.local" {
  chez_init ci
  run chez_cat .gitconfig
  [ "$status" -eq 0 ]
  assert_line_in_output '  path = ~/.gitconfig.local'
}

@test ".gitconfig: contains no embedded credentials" {
  chez_init ci
  run chez_cat .gitconfig
  [ "$status" -eq 0 ]
  [[ ! "$output" =~ gh[pousr]_[A-Za-z0-9]{20,} ]]
  [[ ! "$output" =~ \[url\  ]]
}
