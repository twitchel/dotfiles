#!/usr/bin/env bats
# Tests for run_onchange_after_900_set-default-shell.sh.tmpl
# DEFAULT_SHELL is template-rendered ({{ .hostData.default.defaultShell }} → "zsh").
# Tests exercise the bash logic inline with DEFAULT_SHELL="zsh".

load '../helpers/common'

setup() {
  setup_mocks
}

@test "skips when shell binary does not exist at SHELL_PATH" {
  run bash <<'SCRIPT'
DEFAULT_SHELL="zsh"
SHELL_PATH="/nonexistent/bin/zsh"
if [ ! -x "$SHELL_PATH" ]; then
  echo "Shell not found at $SHELL_PATH — skipping"
  exit 0
fi
echo "shell found"
SCRIPT

  [ "$status" -eq 0 ]
  [[ "$output" == *"Shell not found"* ]]
}

@test "skips chsh when shell is already the default (getent path)" {
  mock getent 0 "testuser:x:1000:1000::/home/testuser:/usr/local/bin/zsh"
  mock chsh 0

  run bash <<SCRIPT
DEFAULT_SHELL="zsh"
SHELL_PATH="/usr/local/bin/zsh"

CURRENT_SHELL="\$(getent passwd "\$(whoami)" | cut -d: -f7)"
if [ "\$CURRENT_SHELL" = "\$SHELL_PATH" ]; then
  echo "Default shell already \$SHELL_PATH, skipping"
  exit 0
fi
chsh -s "\$SHELL_PATH"
SCRIPT

  [ "$status" -eq 0 ]
  [[ "$output" == *"already"* ]]
  assert_mock_not_called chsh
}

@test "runs chsh when shell is not yet the default" {
  # Mock outputs a marker so we can check via $output (more reliable than log files)
  mock chsh 0 "chsh_invoked"
  local fake_shell="${BATS_TEST_TMPDIR}/bin/zsh"
  touch "$fake_shell" && chmod +x "$fake_shell"

  local test_script="${BATS_TEST_TMPDIR}/test_chsh.sh"
  {
    echo '#!/usr/bin/env bash'
    echo 'CURRENT_SHELL="/bin/bash"'
    printf 'SHELL_PATH="%s"\n' "$fake_shell"
    echo '[ "$CURRENT_SHELL" = "$SHELL_PATH" ] && { echo "already set"; exit 0; }'
    echo 'command -v chsh > /dev/null 2>&1 && chsh -s "$SHELL_PATH" "testuser"'
  } > "$test_script"

  run env "PATH=${BATS_TEST_TMPDIR}/bin:/bin:/usr/bin" /bin/bash "$test_script"
  [ "$status" -eq 0 ]
  [[ "$output" == *"chsh_invoked"* ]]
}

@test "adds shell to /etc/shells when missing" {
  local fake_shells="${BATS_TEST_TMPDIR}/shells"
  echo "/bin/bash" > "$fake_shells"
  local fake_shell="${BATS_TEST_TMPDIR}/bin/zsh"
  touch "$fake_shell" && chmod +x "$fake_shell"

  run bash <<SCRIPT
SHELL_PATH="${fake_shell}"
SHELLS_FILE="${fake_shells}"
if ! grep -qF "\$SHELL_PATH" "\$SHELLS_FILE" 2>/dev/null; then
  echo "adding to shells"
  echo "\$SHELL_PATH" >> "\$SHELLS_FILE"
fi
SCRIPT

  [ "$status" -eq 0 ]
  [[ "$output" == *"adding to shells"* ]]
  grep -q "$fake_shell" "$fake_shells"
}

@test "does not duplicate shell in /etc/shells" {
  local fake_shells="${BATS_TEST_TMPDIR}/shells"
  local fake_shell="${BATS_TEST_TMPDIR}/bin/zsh"
  echo "$fake_shell" > "$fake_shells"

  run bash <<SCRIPT
SHELL_PATH="${fake_shell}"
SHELLS_FILE="${fake_shells}"
if ! grep -qF "\$SHELL_PATH" "\$SHELLS_FILE" 2>/dev/null; then
  echo "\$SHELL_PATH" >> "\$SHELLS_FILE"
fi
SCRIPT

  [ "$status" -eq 0 ]
  [ "$(grep -c "$fake_shell" "$fake_shells")" -eq 1 ]
}

@test "falls back to usermod when chsh is unavailable" {
  mock usermod 0 "usermod_invoked"
  local fake_shell="${BATS_TEST_TMPDIR}/bin/zsh"
  touch "$fake_shell" && chmod +x "$fake_shell"

  local test_script="${BATS_TEST_TMPDIR}/test_usermod.sh"
  {
    echo '#!/usr/bin/env bash'
    echo 'CURRENT_SHELL="/bin/bash"'
    printf 'SHELL_PATH="%s"\n' "$fake_shell"
    echo '[ "$CURRENT_SHELL" = "$SHELL_PATH" ] && exit 0'
    echo 'if command -v chsh > /dev/null 2>&1; then'
    echo '  chsh -s "$SHELL_PATH" "testuser"'
    echo 'elif command -v usermod > /dev/null 2>&1; then'
    echo '  usermod -s "$SHELL_PATH" "testuser"'
    echo 'fi'
  } > "$test_script"

  # Mock dir only — on Fedora /bin→/usr/bin so /bin/chsh exists; bash built-ins handle conditionals
  run env "PATH=${BATS_TEST_TMPDIR}/bin" /bin/bash "$test_script"
  [ "$status" -eq 0 ]
  [[ "$output" == *"usermod_invoked"* ]]
  [[ "$output" != *"chsh_invoked"* ]]
}
