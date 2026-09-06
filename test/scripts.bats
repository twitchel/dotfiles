#!/usr/bin/env bats
# Rendering tests for the generated .chezmoiscripts (tap/trust, rpm-ostree,
# cachebust). Scripts are not managed target files, so they are rendered via
# `chezmoi execute-template` rather than `chezmoi cat`.

load helpers/common

SCRIPTS="home/.chezmoiscripts/after"

@test "050 install-brew: default taps are tapped and trusted" {
  chez_init ci
  run chez_template "${SCRIPTS}/run_onchange_after_050_install-brew-packages.sh.tmpl"
  assert_success
  assert_line '$BREWBIN tap "jesseduffield/lazygit"'
  assert_line '$BREWBIN trust "jesseduffield/lazygit"'
}

@test "050 install-brew: host cask taps are tapped and trusted" {
  chez_init coffee-sponge
  run chez_template "${SCRIPTS}/run_onchange_after_050_install-brew-packages.sh.tmpl"
  assert_success
  assert_line '$BREWBIN tap "ublue-os/tap"'
  assert_line '$BREWBIN trust "ublue-os/tap"'
}

@test "050 install-brew: cachebust hash line is present and non-empty" {
  chez_init ci
  run chez_template "${SCRIPTS}/run_onchange_after_050_install-brew-packages.sh.tmpl"
  assert_success
  # e.g. "# .chezmoidata.yaml hash: <64 hex chars>  -"
  assert_line --regexp '^# \.chezmoidata\.yaml hash: [0-9a-f]{64}'
}

@test "040 rpm-ostree: coffee-sponge layers ghostty and zsh" {
  chez_init coffee-sponge
  run chez_template "${SCRIPTS}/run_onchange_after_040_rpm-ostree.sh.tmpl"
  assert_success
  assert_line 'sudo rpm-ostree install "ghostty" || true'
  assert_line 'sudo rpm-ostree install "zsh" || true'
}

@test "040 rpm-ostree: a non-Silverblue host layers nothing" {
  chez_init grease-monkey
  run chez_template "${SCRIPTS}/run_onchange_after_040_rpm-ostree.sh.tmpl"
  assert_success
  refute_output --partial 'rpm-ostree install'
}
