#!/usr/bin/env bats
# Tests for run_onchange_after_900_set-default-shell.sh.tmpl
#
# These source the REAL script (rendered from the template, with
# CHEZMOI_SET_DEFAULT_SHELL_LIB=1 so main() does not auto-run) rather than
# re-implementing its logic inline, so the assertions track the shipped code.
#
# The behaviour under test exists because of a real lockout: the script used to
# chsh to $(brew --prefix)/bin/zsh, which on Linux is
# /home/linuxbrew/.linuxbrew/bin/zsh. sshd cannot exec a shell under /home on an
# SELinux distro, so every login failed with "Permission denied".

load '../helpers/common'

TMPL="run_onchange_after_900_set-default-shell.sh.tmpl"

setup() {
  setup_mocks
  FIXTURE_BIN="${BATS_TEST_TMPDIR}/fixture-bin"
  FAKE_HOME="${BATS_TEST_TMPDIR}/fakehome"
  mkdir -p "$FIXTURE_BIN" "$FAKE_HOME"

  local script
  script="$(render_script_tmpl "${SCRIPTS_AFTER}/${TMPL}")"
  export CHEZMOI_SET_DEFAULT_SHELL_LIB=1
  # shellcheck source=/dev/null
  source "$script"
}

# sudo passthrough so `sudo chsh` / `sudo tee` reach the mocks and real binaries
mock_sudo_passthrough() {
  cat > "${BATS_TEST_TMPDIR}/bin/sudo" <<'SUDO'
#!/bin/bash
exec "$@"
SUDO
  chmod +x "${BATS_TEST_TMPDIR}/bin/sudo"
}

## ---- is_home_path: the guard that prevents the lockout ----

@test "is_home_path rejects the Homebrew Linux prefix" {
  run is_home_path "/home/linuxbrew/.linuxbrew/bin/zsh"
  [ "$status" -eq 0 ]
}

@test "is_home_path rejects other home roots (/var/home, /Users)" {
  run is_home_path "/var/home/danieljones/.linuxbrew/bin/zsh"
  [ "$status" -eq 0 ]
  run is_home_path "/Users/danieljones/bin/zsh"
  [ "$status" -eq 0 ]
}

@test "is_home_path rejects a path under \$HOME" {
  HOME="$FAKE_HOME" run is_home_path "${FAKE_HOME}/bin/zsh"
  [ "$status" -eq 0 ]
}

@test "is_home_path accepts system and macOS Homebrew locations" {
  run is_home_path "/usr/bin/zsh"
  [ "$status" -ne 0 ]
  run is_home_path "/bin/zsh"
  [ "$status" -ne 0 ]
  run is_home_path "/opt/homebrew/bin/zsh"
  [ "$status" -ne 0 ]
}

## ---- resolve_login_shell ----

@test "resolve_login_shell skips a home-dir shell for a system one" {
  make_fake_shell "${FAKE_HOME}/.linuxbrew/bin/zsh"
  make_fake_shell "${FIXTURE_BIN}/zsh"

  HOME="$FAKE_HOME" run resolve_login_shell "${FAKE_HOME}/.linuxbrew/bin/zsh" "${FIXTURE_BIN}/zsh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Rejecting ${FAKE_HOME}/.linuxbrew/bin/zsh"* ]]
  [[ "$output" == *"${FIXTURE_BIN}/zsh"* ]]
}

@test "resolve_login_shell rejects a system path symlinked into a home dir" {
  make_fake_shell "${FAKE_HOME}/.linuxbrew/bin/zsh"
  ln -s "${FAKE_HOME}/.linuxbrew/bin/zsh" "${FIXTURE_BIN}/zsh"

  HOME="$FAKE_HOME" run resolve_login_shell "${FIXTURE_BIN}/zsh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Rejecting ${FIXTURE_BIN}/zsh"* ]]
}

@test "resolve_login_shell fails when every candidate is under a home dir" {
  make_fake_shell "${FAKE_HOME}/.linuxbrew/bin/zsh"

  HOME="$FAKE_HOME" run resolve_login_shell "${FAKE_HOME}/.linuxbrew/bin/zsh"
  [ "$status" -ne 0 ]
}

@test "resolve_login_shell skips candidates that do not exist" {
  make_fake_shell "${FIXTURE_BIN}/zsh"

  run resolve_login_shell "/nonexistent/bin/zsh" "${FIXTURE_BIN}/zsh"
  [ "$status" -eq 0 ]
  [ "$output" = "${FIXTURE_BIN}/zsh" ]
}

@test "resolve_login_shell rejects an executable that is not a working shell" {
  printf '#!/bin/sh\nexit 1\n' > "${FIXTURE_BIN}/zsh"
  chmod +x "${FIXTURE_BIN}/zsh"

  run resolve_login_shell "${FIXTURE_BIN}/zsh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"not executable as a shell"* ]]
}

## ---- main(): end-to-end selection ----

@test "main never chsh's to a Homebrew shell under a home directory" {
  # Reproduces the lockout: brew --prefix points inside HOME, system zsh exists.
  make_fake_shell "${FAKE_HOME}/.linuxbrew/bin/zsh"
  make_fake_shell "${FIXTURE_BIN}/zsh"
  cat > "${BATS_TEST_TMPDIR}/bin/brew" <<BREW
#!/bin/sh
echo "${FAKE_HOME}/.linuxbrew"
BREW
  chmod +x "${BATS_TEST_TMPDIR}/bin/brew"
  mock getent 0 "testuser:x:1000:1000::/home/testuser:/bin/bash"
  mock chsh 0 "chsh_invoked"
  mock_sudo_passthrough

  HOME="$FAKE_HOME" \
    BREWBIN="${BATS_TEST_TMPDIR}/bin/brew" \
    SHELL_SEARCH_PATH="$FIXTURE_BIN" \
    SHELLS_FILE="${BATS_TEST_TMPDIR}/shells" \
    run main

  [ "$status" -eq 0 ]
  [[ "$output" == *"Selected login shell: ${FIXTURE_BIN}/zsh"* ]]
  assert_mock_called_with chsh "${FIXTURE_BIN}/zsh"
  run grep -F "${FAKE_HOME}" "${BATS_TEST_TMPDIR}/mock_chsh.log"
  [ "$status" -ne 0 ]
}

@test "main leaves the shell unchanged when only a home-dir shell exists" {
  make_fake_shell "${FAKE_HOME}/.linuxbrew/bin/zsh"
  cat > "${BATS_TEST_TMPDIR}/bin/brew" <<BREW
#!/bin/sh
echo "${FAKE_HOME}/.linuxbrew"
BREW
  chmod +x "${BATS_TEST_TMPDIR}/bin/brew"
  mock getent 0 "testuser:x:1000:1000::/home/testuser:/bin/bash"
  mock chsh 0 "chsh_invoked"
  mock usermod 0 "usermod_invoked"
  mock_sudo_passthrough

  HOME="$FAKE_HOME" \
    BREWBIN="${BATS_TEST_TMPDIR}/bin/brew" \
    SHELL_SEARCH_PATH="${BATS_TEST_TMPDIR}/empty" \
    SHELLS_FILE="${BATS_TEST_TMPDIR}/shells" \
    run main

  [ "$status" -eq 0 ]
  [[ "$output" == *"No usable system zsh found"* ]]
  assert_mock_not_called chsh
  assert_mock_not_called usermod
}

@test "main never writes a home-dir path into /etc/shells" {
  make_fake_shell "${FAKE_HOME}/.linuxbrew/bin/zsh"
  make_fake_shell "${FIXTURE_BIN}/zsh"
  cat > "${BATS_TEST_TMPDIR}/bin/brew" <<BREW
#!/bin/sh
echo "${FAKE_HOME}/.linuxbrew"
BREW
  chmod +x "${BATS_TEST_TMPDIR}/bin/brew"
  local shells="${BATS_TEST_TMPDIR}/shells"
  echo "/bin/bash" > "$shells"
  mock getent 0 "testuser:x:1000:1000::/home/testuser:/bin/bash"
  mock chsh 0
  mock_sudo_passthrough

  HOME="$FAKE_HOME" BREWBIN="${BATS_TEST_TMPDIR}/bin/brew" \
    SHELL_SEARCH_PATH="$FIXTURE_BIN" SHELLS_FILE="$shells" main

  grep -qF "${FIXTURE_BIN}/zsh" "$shells"
  run grep -F "$FAKE_HOME" "$shells"
  [ "$status" -ne 0 ]
}

@test "main does not duplicate an entry already in /etc/shells" {
  make_fake_shell "${FIXTURE_BIN}/zsh"
  local shells="${BATS_TEST_TMPDIR}/shells"
  echo "${FIXTURE_BIN}/zsh" > "$shells"
  mock getent 0 "testuser:x:1000:1000::/home/testuser:/bin/bash"
  mock chsh 0
  mock_sudo_passthrough

  SHELL_SEARCH_PATH="$FIXTURE_BIN" SHELLS_FILE="$shells" main

  [ "$(grep -cF "${FIXTURE_BIN}/zsh" "$shells")" -eq 1 ]
}

@test "main skips chsh when the shell is already the default" {
  make_fake_shell "${FIXTURE_BIN}/zsh"
  mock getent 0 "testuser:x:1000:1000::/home/testuser:${FIXTURE_BIN}/zsh"
  mock chsh 0 "chsh_invoked"
  mock_sudo_passthrough

  SHELL_SEARCH_PATH="$FIXTURE_BIN" SHELLS_FILE="${BATS_TEST_TMPDIR}/shells" run main

  [ "$status" -eq 0 ]
  [[ "$output" == *"already"* ]]
  assert_mock_not_called chsh
}

@test "main falls back to usermod when chsh is unavailable" {
  make_fake_shell "${FIXTURE_BIN}/zsh"
  mock getent 0 "testuser:x:1000:1000::/home/testuser:/bin/bash"
  mock chsh 0 "chsh_invoked"
  mock usermod 0 "usermod_invoked"
  mock_sudo_passthrough

  # Shadow the `command` builtin so `command -v chsh` reports chsh as missing,
  # without having to strip the real /usr/bin off PATH (the script needs grep,
  # awk, readlink and friends from there).
  command() {
    if [ "$1" = "-v" ] && [ "$2" = "chsh" ]; then return 1; fi
    builtin command "$@"
  }

  SHELL_SEARCH_PATH="$FIXTURE_BIN" SHELLS_FILE="${BATS_TEST_TMPDIR}/shells" run main

  [ "$status" -eq 0 ]
  assert_mock_called_with usermod "${FIXTURE_BIN}/zsh"
  assert_mock_not_called chsh
}

@test "resolve_login_shell returns the stable path, not the symlink target" {
  # /opt/homebrew/bin/zsh points into ../Cellar/zsh/<version>/bin/zsh. Setting
  # the Cellar path as the login shell breaks on the next brew upgrade.
  make_fake_shell "${FIXTURE_BIN}/Cellar/zsh/5.9/bin/zsh"
  ln -s "${FIXTURE_BIN}/Cellar/zsh/5.9/bin/zsh" "${FIXTURE_BIN}/zsh"

  run resolve_login_shell "${FIXTURE_BIN}/zsh"
  [ "$status" -eq 0 ]
  [ "$output" = "${FIXTURE_BIN}/zsh" ]
}

@test "is_home_path rejects a resolved path when \$HOME itself is a symlink" {
  # The macOS condition: /var is a symlink to /private/var, so readlink -f gives
  # a path that shares no prefix with an unresolved $HOME.
  mkdir -p "${BATS_TEST_TMPDIR}/real_home/bin"
  ln -s "${BATS_TEST_TMPDIR}/real_home" "${BATS_TEST_TMPDIR}/link_home"

  HOME="${BATS_TEST_TMPDIR}/link_home" run is_home_path "${BATS_TEST_TMPDIR}/real_home/bin/zsh"
  [ "$status" -eq 0 ]
}

@test "resolve_login_shell rejects a shell reached through a symlinked \$HOME" {
  mkdir -p "${BATS_TEST_TMPDIR}/real_home"
  ln -s "${BATS_TEST_TMPDIR}/real_home" "${BATS_TEST_TMPDIR}/link_home"
  make_fake_shell "${BATS_TEST_TMPDIR}/link_home/.linuxbrew/bin/zsh"

  HOME="${BATS_TEST_TMPDIR}/link_home" run resolve_login_shell "${BATS_TEST_TMPDIR}/link_home/.linuxbrew/bin/zsh"
  [ "$status" -ne 0 ]
}

@test "is_home_path rejects a home shell reached via a symlinked parent (macOS /var topology)" {
  # macOS: BATS_TEST_TMPDIR sits under /var, which is a symlink to /private/var,
  # so the path handed in and $HOME can resolve through different prefixes.
  local real="${BATS_TEST_TMPDIR}/base_real" link="${BATS_TEST_TMPDIR}/base_link"
  mkdir -p "${real}/real_home/bin"
  ln -s "${real}/real_home" "${real}/link_home"
  ln -s "$real" "$link"

  HOME="${link}/link_home" run is_home_path "${link}/real_home/bin/zsh"
  [ "$status" -eq 0 ]
}
