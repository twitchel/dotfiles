#!/usr/bin/env bats
# Tests for run_onchange_after_020_gnome-extensions.sh.tmpl
# This script has no template variables in the guard logic — run directly.
# Extension-list section has template vars; tested inline.

load '../helpers/common'

SCRIPT="${SCRIPTS_AFTER}/run_onchange_after_020_gnome-extensions.sh.tmpl"

setup() {
  setup_mocks
}

@test "skips when MACHINE_TYPE is server" {
  run env MACHINE_TYPE="server" bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Not a workstation"* ]]
}

@test "skips when gnome-extensions is not installed" {
  run env MACHINE_TYPE="workstation" DISPLAY=":0" bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"not a GNOME system"* ]]
}

@test "skips when no display session is available" {
  mock gnome-extensions 0

  run env MACHINE_TYPE="workstation" DISPLAY="" WAYLAND_DISPLAY="" bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"No display session"* ]]
}

@test "installs gext via pipx when not present" {
  mock gnome-extensions 0
  mock pipx 0 "pipx_invoked"

  # HOME overridden so $HOME/.local/bin/gext doesn't exist after mock pipx runs
  run env "PATH=${BATS_TEST_TMPDIR}/bin:/bin" HOME="${BATS_TEST_TMPDIR}" \
    MACHINE_TYPE="workstation" DISPLAY=":0" /bin/bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"pipx_invoked"* ]]
}

@test "falls back to pip3 when pipx is unavailable" {
  mock gnome-extensions 0
  mock pip3 0 "pip3_invoked"

  run env "PATH=${BATS_TEST_TMPDIR}/bin:/bin" HOME="${BATS_TEST_TMPDIR}" \
    MACHINE_TYPE="workstation" DISPLAY=":0" /bin/bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"pip3_invoked"* ]]
}

@test "skips gracefully when neither pipx nor pip3 available" {
  mock gnome-extensions 0

  # Restrict PATH to mock dir + /bin only — excludes real pip3/pipx (never in /bin)
  run env "PATH=${BATS_TEST_TMPDIR}/bin:/bin" MACHINE_TYPE="workstation" DISPLAY=":0" /bin/bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Neither pipx nor pip3"* ]]
}

@test "skips already-installed extensions" {
  mock gext 0
  # gnome-extensions list returns our extension as installed
  mock gnome-extensions 0 "appindicatorsupport@rgcjonas.gmail.com"

  run bash <<SCRIPT
INSTALLED="\$(gnome-extensions list)"
UUID="appindicatorsupport@rgcjonas.gmail.com"
if echo "\$INSTALLED" | grep -qF "\$UUID"; then
  echo "Already installed: \$UUID"
else
  echo "Installing: \$UUID"
  gext install "\$UUID"
fi
SCRIPT

  [ "$status" -eq 0 ]
  [[ "$output" == *"Already installed"* ]]
  assert_mock_not_called gext
}

@test "installs extensions not yet present" {
  mock gext 0 "gext_installed"
  mock gnome-extensions 0 ""  # list returns empty (nothing installed)

  run bash <<SCRIPT
INSTALLED="\$(gnome-extensions list)"
UUID="blur-my-shell@aunetx"
if echo "\$INSTALLED" | grep -qF "\$UUID"; then
  echo "Already installed: \$UUID"
else
  echo "Installing: \$UUID"
  gext install "\$UUID"
fi
SCRIPT

  [ "$status" -eq 0 ]
  [[ "$output" == *"Installing"* ]]
  assert_mock_called gext
  assert_mock_called_with gext "install"
}

@test "continues after failed extension install" {
  mock gext 1  # gext always fails
  mock gnome-extensions 0 ""

  run bash <<'SCRIPT'
INSTALLED=""
for UUID in "ext1@author" "ext2@author"; do
  if echo "$INSTALLED" | grep -qF "$UUID"; then
    echo "Already installed: $UUID"
  else
    gext install "$UUID" || echo "⚠️  Failed to install $UUID"
  fi
done
echo "done"
SCRIPT

  [ "$status" -eq 0 ]
  [[ "$output" == *"Failed to install"* ]]
  [[ "$output" == *"done"* ]]
}
