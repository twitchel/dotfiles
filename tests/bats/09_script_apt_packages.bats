#!/usr/bin/env bats
# Tests for run_onchange_before_006_apt-packages.sh.tmpl
#
# Same approach as 08: real chezmoi render, then run with PATH restricted to the
# mock bin dir. grep is symlinked in because the script pipes dpkg-query into it.

load '../helpers/common'

TMPL="run_onchange_before_006_apt-packages.sh.tmpl"

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
  ln -sf "$(command -v grep)" "${MOCK_BIN}/grep"
  SCRIPT="$(render_script_tmpl "${SCRIPTS_BEFORE}/${TMPL}")"
}

run_script() {
  run env "PATH=${MOCK_BIN}" "$BASH_BIN" "$SCRIPT"
}

# dpkg-query mock reporting the named packages as installed, others missing
mock_dpkg_installed() {
  cat > "${MOCK_BIN}/dpkg-query" <<DPKG
#!/bin/bash
echo "\$*" >> "${BATS_TEST_TMPDIR}/mock_dpkg-query.log"
for installed in $*; do
  if [ "\$3" = "\$installed" ]; then
    echo "install ok installed"
    exit 0
  fi
done
exit 1
DPKG
  chmod +x "${MOCK_BIN}/dpkg-query"
}

@test "skips when apt-get is not installed" {
  run_script
  [ "$status" -eq 0 ]
  [[ "$output" == *"No apt-get on system"* ]]
}

@test "queries every package from chezmoi data" {
  mock apt-get 0
  mock sudo 0
  mock_dpkg_installed zsh git

  run_script
  [ "$status" -eq 0 ]
  assert_mock_called_with dpkg-query "zsh"
  assert_mock_called_with dpkg-query "git"
}

@test "installs nothing and never calls sudo when all packages are present" {
  mock apt-get 0
  mock sudo 0
  mock_dpkg_installed zsh git

  run_script
  [ "$status" -eq 0 ]
  [[ "$output" == *"All apt packages already installed"* ]]
  assert_mock_not_called sudo
}

@test "does not run apt-get update when there is nothing to install" {
  mock apt-get 0
  mock sudo 0
  mock_dpkg_installed zsh git

  run_script
  [ "$status" -eq 0 ]
  assert_mock_not_called sudo
}

@test "updates before installing, and installs only the missing packages" {
  mock apt-get 0
  mock sudo 0
  mock_dpkg_installed git # zsh missing

  run_script
  [ "$status" -eq 0 ]
  assert_mock_called_with sudo "apt-get update"
  assert_mock_called_with sudo "apt-get install -y zsh"
  run grep -F "install -y zsh git" "${BATS_TEST_TMPDIR}/mock_sudo.log"
  [ "$status" -ne 0 ]
}

@test "runs apt-get directly without sudo when already root" {
  mock apt-get 0
  mock sudo 0
  mock id 0 "0" # ubuntu:26.04 ships no sudo at all
  mock_dpkg_installed git # zsh missing

  run_script
  [ "$status" -eq 0 ]
  assert_mock_called_with apt-get "update"
  assert_mock_called_with apt-get "install -y zsh"
  assert_mock_not_called sudo
}
