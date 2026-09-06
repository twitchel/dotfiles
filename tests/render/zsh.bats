#!/usr/bin/env bats
# Render tier: the generated zsh bootstrap config.

load '../helpers/common'

@test "bootstrap.zshrc: Homebrew shellenv uses the per-OS BREWBIN path" {
  chez_init ci
  run chez_cat .config/zsh/bootstrap.zshrc
  [ "$status" -eq 0 ]
  # BREWBIN is set per-OS in .chezmoi.yaml.tmpl, so assert the path for the host
  # actually running the suite — this runs on both Linux containers and macOS.
  if [ "$(uname -s)" = "Darwin" ]; then
    assert_line_in_output 'eval "$(/opt/homebrew/bin/brew shellenv)"'
  else
    assert_line_in_output 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"'
  fi
}

@test "bootstrap.zshrc: prepends ~/.local/bin to PATH" {
  chez_init ci
  run chez_cat .config/zsh/bootstrap.zshrc
  [ "$status" -eq 0 ]
  assert_line_in_output 'export PATH="$HOME/.local/bin:$PATH"'
}

@test "bootstrap.zshrc: ssh-agent eval is silenced" {
  chez_init ci
  run chez_cat .config/zsh/bootstrap.zshrc
  [ "$status" -eq 0 ]
  assert_line_in_output 'command -v ssh-agent > /dev/null && eval "$(ssh-agent)" > /dev/null'
}
