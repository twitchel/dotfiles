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
