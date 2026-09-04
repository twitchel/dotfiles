#!/usr/bin/env bats
# Tests for home/dot_config/zsh/bootstrap.zshrc.tmpl

load '../helpers/common'

BOOTSTRAP="${REPO_ROOT}/home/dot_config/zsh/bootstrap.zshrc.tmpl"

@test "node is in default brew packages" {
  run yq eval '.hostData.default.packages.brew[] | select(. == "node")' "${CHEZMOIDATA}"
  [ "$output" = "node" ]
}

@test "ssh-agent command -v output is silenced" {
  run grep 'command -v ssh-agent > /dev/null' "$BOOTSTRAP"
  [ "$status" -eq 0 ]
}
