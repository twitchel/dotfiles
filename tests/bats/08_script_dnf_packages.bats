#!/usr/bin/env bats
# Tests for run_onchange_before_005_dnf-packages.sh.tmpl
#
# The script is rendered with a real chezmoi render, so the package list under
# test is the actual hostData.default.packages.dnf list from .chezmoidata.yaml.
# It is then run with PATH restricted to the mock bin dir, which is what lets a
# test make dnf or rpm-ostree "absent".

load '../helpers/common'

TMPL="run_onchange_before_005_dnf-packages.sh.tmpl"

setup() {
  setup_mocks
  MOCK_BIN="${BATS_TEST_TMPDIR}/bin"
  BASH_BIN="$(command -v bash)" # absolute: PATH is stripped to the mocks below
  # PATH is stripped to the mock dir, so link in the real coreutils the
  # scripts genuinely need (env for the sudo-less path, id for the root check).
  ln -sf "$(command -v env)" "${BATS_TEST_TMPDIR}/bin/env"
  # Pin id: CI containers run as root, which would otherwise flip every
  # test onto the sudo-less path. Root behaviour has its own test below.
  mock id 0 "1000"
  SCRIPT="$(render_script_tmpl "${SCRIPTS_BEFORE}/${TMPL}")"
}

# Run the rendered script seeing only the mocks
run_script() {
  run env "PATH=${MOCK_BIN}" "$BASH_BIN" "$SCRIPT"
}

# rpm mock reporting the named packages as installed, everything else missing
mock_rpm_installed() {
  cat > "${MOCK_BIN}/rpm" <<RPM
#!/bin/bash
echo "\$*" >> "${BATS_TEST_TMPDIR}/mock_rpm.log"
for installed in $*; do
  [ "\$2" = "\$installed" ] && exit 0
done
exit 1
RPM
  chmod +x "${MOCK_BIN}/rpm"
}

@test "skips when dnf is not installed" {
  run_script
  [ "$status" -eq 0 ]
  [[ "$output" == *"No dnf on system"* ]]
}

@test "skips on an atomic host where rpm-ostree owns layering" {
  mock dnf 0
  mock rpm-ostree 0
  mock sudo 0

  run_script
  [ "$status" -eq 0 ]
  [[ "$output" == *"Atomic host"* ]]
  assert_mock_not_called sudo
}

@test "queries every package from chezmoi data" {
  mock dnf 0
  mock sudo 0
  mock_rpm_installed zsh git

  run_script
  [ "$status" -eq 0 ]
  assert_mock_called_with rpm "zsh"
  assert_mock_called_with rpm "git"
}

@test "installs nothing and never calls sudo when all packages are present" {
  mock dnf 0
  mock sudo 0
  mock_rpm_installed zsh git

  run_script
  [ "$status" -eq 0 ]
  [[ "$output" == *"All dnf packages already installed"* ]]
  assert_mock_not_called sudo
}

@test "installs only the missing packages" {
  mock dnf 0
  mock sudo 0
  mock_rpm_installed git # zsh missing

  run_script
  [ "$status" -eq 0 ]
  assert_mock_called_with sudo "dnf install -y zsh"
  run grep -F "git" "${BATS_TEST_TMPDIR}/mock_sudo.log"
  [ "$status" -ne 0 ]
}

@test "runs dnf directly without sudo when already root" {
  mock dnf 0
  mock sudo 0
  mock id 0 "0" # ubuntu:26.04 and friends ship no sudo at all
  mock_rpm_installed git # zsh missing

  run_script
  [ "$status" -eq 0 ]
  assert_mock_called_with dnf "install -y zsh"
  assert_mock_not_called sudo
}
