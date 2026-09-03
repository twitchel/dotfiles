#!/usr/bin/env bats
# Tests for run_onchange_after_010_flatpak-postinstall.sh.tmpl
# This script has no template variables — it can be run directly.

load '../helpers/common'

SCRIPT="${SCRIPTS_AFTER}/run_onchange_after_010_flatpak-postinstall.sh.tmpl"

setup() {
  setup_mocks
}

@test "skips when MACHINE_TYPE is server" {
  run env MACHINE_TYPE="server" OS_VARIANT="" bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Not a workstation"* ]]
}

@test "skips when flatpak is not installed" {
  # No flatpak mock in PATH → command -v flatpak fails
  run env MACHINE_TYPE="workstation" OS_VARIANT="" bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"flatpak not found"* ]]
}

@test "removes filtered Flathub remotes on silverblue" {
  mock flatpak 0

  run env MACHINE_TYPE="workstation" OS_VARIANT="silverblue" bash "$SCRIPT"
  [ "$status" -eq 0 ]
  assert_mock_called_with flatpak "remote-delete flathub"
  assert_mock_called_with flatpak "remote-delete fedora"
}

@test "removes filtered Flathub remotes on bazzite" {
  mock flatpak 0

  run env MACHINE_TYPE="workstation" OS_VARIANT="bazzite" bash "$SCRIPT"
  [ "$status" -eq 0 ]
  assert_mock_called_with flatpak "remote-delete flathub"
}

@test "removes filtered Flathub remotes on kinoite" {
  mock flatpak 0

  run env MACHINE_TYPE="workstation" OS_VARIANT="kinoite" bash "$SCRIPT"
  [ "$status" -eq 0 ]
  assert_mock_called_with flatpak "remote-delete flathub"
}

@test "does NOT remove remotes on standard Ubuntu (non-atomic)" {
  mock flatpak 0

  run env MACHINE_TYPE="workstation" OS_VARIANT="" bash "$SCRIPT"
  [ "$status" -eq 0 ]
  # remote-delete should not appear for non-atomic variants
  if assert_mock_called flatpak; then
    run grep "remote-delete" "${BATS_TEST_TMPDIR}/mock_flatpak.log"
    [ "$status" -ne 0 ]
  fi
}

@test "always calls remote-add --if-not-exists for full Flathub" {
  mock flatpak 0

  run env MACHINE_TYPE="workstation" OS_VARIANT="silverblue" bash "$SCRIPT"
  [ "$status" -eq 0 ]
  assert_mock_called_with flatpak "remote-add --if-not-exists flathub"
}

@test "remote-delete failure does not abort script" {
  # remote-delete returns 1 (remote absent), but remote-add and update succeed
  cat > "${BATS_TEST_TMPDIR}/bin/flatpak" <<MOCK
#!/usr/bin/env bash
echo "\$*" >> "${BATS_TEST_TMPDIR}/mock_flatpak.log"
[[ "\$1" == "remote-delete" ]] && exit 1
exit 0
MOCK
  chmod +x "${BATS_TEST_TMPDIR}/bin/flatpak"

  run env "PATH=${BATS_TEST_TMPDIR}/bin:${PATH}" MACHINE_TYPE="workstation" OS_VARIANT="silverblue" /bin/bash "$SCRIPT"
  [ "$status" -eq 0 ]
}
