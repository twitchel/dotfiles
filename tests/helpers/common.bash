#!/usr/bin/env bash

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPTS_BEFORE="${REPO_ROOT}/home/.chezmoiscripts/before"
SCRIPTS_AFTER="${REPO_ROOT}/home/.chezmoiscripts/after"
CHEZMOIDATA="${REPO_ROOT}/home/.chezmoidata.yaml"

# Prepend a per-test mock bin dir to PATH
setup_mocks() {
  mkdir -p "${BATS_TEST_TMPDIR}/bin"
  export PATH="${BATS_TEST_TMPDIR}/bin:${PATH}"
}

# Create a mock executable that logs its args and returns a given exit code
# Usage: mock <name> [exit_code=0] [stdout=""]
mock() {
  local name="$1"
  local exit_code="${2:-0}"
  local stdout="${3:-}"
  local log="${BATS_TEST_TMPDIR}/mock_${name}.log"
  mkdir -p "${BATS_TEST_TMPDIR}/bin"
  # rm first: the target may be a symlink to a real binary (see the coreutils
  # links in 08/09), and `cat >` would write straight through to it.
  rm -f "${BATS_TEST_TMPDIR}/bin/${name}"
  cat > "${BATS_TEST_TMPDIR}/bin/${name}" <<SCRIPT
#!/bin/bash
echo "\$*" >> "${log}"
${stdout:+printf '%s\n' "${stdout}"}
exit ${exit_code}
SCRIPT
  chmod +x "${BATS_TEST_TMPDIR}/bin/${name}"
}

# True if mock was ever called
assert_mock_called() {
  local log="${BATS_TEST_TMPDIR}/mock_${1}.log"
  [[ -f "$log" ]]
}

# True if mock was never called
assert_mock_not_called() {
  local log="${BATS_TEST_TMPDIR}/mock_${1}.log"
  [[ ! -f "$log" ]]
}

# True if mock was called with args containing the given string
assert_mock_called_with() {
  local log="${BATS_TEST_TMPDIR}/mock_${1}.log"
  grep -qF "$2" "$log"
}

# Isolated chezmoi HOME seeded with the prompt answers, so template rendering in
# the tests never depends on the developer's own chezmoi state. Initialised once
# per test.
_chez_test_home() {
  if [ -z "${CHEZ_TEST_HOME:-}" ]; then
    CHEZ_TEST_HOME="${BATS_TEST_TMPDIR}/chezmoi-home"
    mkdir -p "${CHEZ_TEST_HOME}/.config/chezmoi"
    cat > "${CHEZ_TEST_HOME}/.config/chezmoi/chezmoi.yaml" <<EOF
data:
  customHostname: test-host
  email: test@example.com
  machineType: server
EOF
    env -u CI HOME="${CHEZ_TEST_HOME}" chezmoi init -S "${REPO_ROOT}" --no-tty > /dev/null
  fi
  echo "$CHEZ_TEST_HOME"
}

# Render a .chezmoiscripts template into a runnable bash script via a real
# chezmoi render, so package lists and data under test are the actual values
# from .chezmoidata.yaml. Echoes the path of the rendered script.
render_script_tmpl() {
  local src="$1" home out
  out="${BATS_TEST_TMPDIR}/$(basename "$src" .tmpl)"
  home="$(_chez_test_home)"
  env -u CI HOME="$home" chezmoi execute-template -S "${REPO_ROOT}" --no-tty < "$src" > "$out"
  chmod +x "$out"
  echo "$out"
}

# Create a fake but genuinely executable shell at the given path. It accepts
# `-c <cmd>` and exits 0, so it passes the script's exec smoke test.
make_fake_shell() {
  local path="$1"
  mkdir -p "$(dirname "$path")"
  printf '#!/bin/sh\nexit 0\n' > "$path"
  chmod +x "$path"
}
