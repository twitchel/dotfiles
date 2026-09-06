#!/usr/bin/env bats
# Render tier: the generated .chezmoiscripts. Scripts are not managed target
# files, so they render via `chezmoi execute-template` rather than `chezmoi cat`.

load '../helpers/common'

SCRIPTS="home/.chezmoiscripts/after"

@test "050 install-brew: default formula taps are tapped" {
  # trust is deliberately cask-only; formula taps do not need it.
  chez_init ci
  run chez_template "${SCRIPTS}/run_onchange_after_050_install-brew-packages.sh.tmpl"
  [ "$status" -eq 0 ]
  assert_line_in_output '$BREWBIN tap "jesseduffield/lazygit"'
  refute_output_contains '$BREWBIN trust "jesseduffield/lazygit"'
}

@test "050 install-brew: host cask taps are tapped and trusted" {
  chez_init coffee-sponge
  run chez_template "${SCRIPTS}/run_onchange_after_050_install-brew-packages.sh.tmpl"
  [ "$status" -eq 0 ]
  assert_line_in_output '$BREWBIN tap "ublue-os/tap"'
  assert_line_in_output '$BREWBIN trust "ublue-os/tap"'
}

@test "050 install-brew: cachebust hash line is present and non-empty" {
  chez_init ci
  run chez_template "${SCRIPTS}/run_onchange_after_050_install-brew-packages.sh.tmpl"
  [ "$status" -eq 0 ]
  assert_line_matches '^# \.chezmoidata\.yaml hash: [0-9a-f]{64}'
}

@test "040 rpm-ostree: coffee-sponge queues ghostty and zsh for layering" {
  chez_init coffee-sponge
  run chez_template "${SCRIPTS}/run_onchange_after_040_rpm-ostree.sh.tmpl"
  [ "$status" -eq 0 ]
  assert_line_in_output '  PACKAGES_TO_INSTALL+=("ghostty")'
  assert_line_in_output '  PACKAGES_TO_INSTALL+=("zsh")'
  # Batched into one call, not one call per package
  assert_line_in_output 'sudo rpm-ostree install "${PACKAGES_TO_INSTALL[@]}"'
}

@test "040 rpm-ostree: a host with no rpmOstree packages exits early" {
  chez_init grease-monkey
  run chez_template "${SCRIPTS}/run_onchange_after_040_rpm-ostree.sh.tmpl"
  [ "$status" -eq 0 ]
  assert_line_in_output 'echo "📝 No rpmOstree packages for grease-monkey, skipping"'
  refute_output_contains 'PACKAGES_TO_INSTALL+=('
}

@test "005 dnf: package list renders from chezmoi data" {
  chez_init ci
  run chez_template "home/.chezmoiscripts/before/run_onchange_before_005_dnf-packages.sh.tmpl"
  [ "$status" -eq 0 ]
  assert_line_in_output '  PACKAGES_TO_INSTALL+=("zsh")'
  assert_line_in_output '  PACKAGES_TO_INSTALL+=("git")'
}

@test "006 apt: package list renders from chezmoi data" {
  chez_init ci
  run chez_template "home/.chezmoiscripts/before/run_onchange_before_006_apt-packages.sh.tmpl"
  [ "$status" -eq 0 ]
  assert_line_in_output '  PACKAGES_TO_INSTALL+=("zsh")'
  assert_line_in_output '  PACKAGES_TO_INSTALL+=("git")'
}
