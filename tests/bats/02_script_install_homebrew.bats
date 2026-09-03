#!/usr/bin/env bats
# Tests for run_onchange_before_010_install-homebrew.sh.tmpl
# This script has no template variables — it can be run directly.

load '../helpers/common'

SCRIPT="${SCRIPTS_BEFORE}/run_onchange_before_010_install-homebrew.sh.tmpl"

setup() {
  setup_mocks
}

@test "skips when OS is not darwin or linux" {
  run env OS="windows" BREWBIN="/nonexistent" BREWPATH="/nonexistent" bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"only supported on macOS and Linux"* ]]
}

@test "skips install when BREWBIN is already executable" {
  local fake_brew="${BATS_TEST_TMPDIR}/bin/brew"
  touch "$fake_brew" && chmod +x "$fake_brew"

  run env OS="linux" BREWPATH="${BATS_TEST_TMPDIR}/bin" BREWBIN="$fake_brew" bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"already installed"* ]]
}

@test "proceeds with install when BREWBIN does not exist" {
  # Mock curl to return empty output (prevents real Homebrew download)
  mock curl 0

  # Use /bin/bash explicitly so the mock bash in PATH is not picked up
  run env "PATH=${BATS_TEST_TMPDIR}/bin:${PATH}" OS="linux" BREWPATH="/nonexistent" BREWBIN="/nonexistent/brew" /bin/bash "$SCRIPT"
  [[ "$output" == *"proceeding with installation"* ]]
}

@test "BREWBIN check uses quoted variable (no word-split)" {
  # Verify the script has proper quoting — grep for the quoted form
  run grep '"\$OS"' "$SCRIPT"
  [ "$status" -eq 0 ]
}
