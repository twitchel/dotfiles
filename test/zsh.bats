#!/usr/bin/env bats
# Rendering tests for the generated zsh bootstrap config.

load helpers/common

@test "bootstrap.zshrc: Homebrew shellenv uses the per-OS BREWBIN path" {
  chez_init ci
  run chez_cat .config/zsh/bootstrap.zshrc
  assert_success
  # On a Linux container BREWBIN resolves to the linuxbrew path.
  assert_line 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"'
}

@test "bootstrap.zshrc: prepends ~/.local/bin to PATH" {
  chez_init ci
  run chez_cat .config/zsh/bootstrap.zshrc
  assert_success
  assert_line 'export PATH="$HOME/.local/bin:$PATH"'
}

@test "bootstrap.zshrc: ssh-agent eval is silenced" {
  chez_init ci
  run chez_cat .config/zsh/bootstrap.zshrc
  assert_success
  assert_line 'command -v ssh-agent && eval ssh-agent > /dev/null'
}
