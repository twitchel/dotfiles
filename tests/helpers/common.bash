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

# ---------------------------------------------------------------------------
# chezmoi rendering
#
# The config template uses promptStringOnce for customHostname/email, which
# opens /dev/tty directly and cannot be driven by --promptString. Instead we
# pre-seed an isolated chezmoi config so promptStringOnce finds its answers and
# skips the prompt, then run a normal init to materialise the resolved data
# (hostname lowercasing, osid, BREWBIN, ...). machineType is seeded too: a bare
# container has no VARIANT_ID, which would otherwise prompt.
# ---------------------------------------------------------------------------

# chez_init <hostname> [email]
# Sets up an isolated chezmoi HOME under the per-test tmpdir and inits it.
# Exports CHEZ_HOME for the helpers below. CI is unset so a CI=true environment
# does not pin the hostname to "ci".
chez_init() {
  local host="$1" email="${2:-test@example.com}"
  CHEZ_HOME="${BATS_TEST_TMPDIR}/home-${host}"
  mkdir -p "${CHEZ_HOME}/.config/chezmoi"
  cat > "${CHEZ_HOME}/.config/chezmoi/chezmoi.yaml" <<EOF
data:
  customHostname: ${host}
  email: ${email}
  machineType: server
EOF
  env -u CI HOME="${CHEZ_HOME}" chezmoi init -S "${REPO_ROOT}" --no-tty > /dev/null
}

# chez <args...> — run a chezmoi subcommand against the isolated HOME.
chez() {
  env -u CI HOME="${CHEZ_HOME}" chezmoi "$@" -S "${REPO_ROOT}" --no-tty
}

# chez_cat <target-relpath> — render a managed target file, e.g. .config/brew/Brewfile
chez_cat() {
  chez cat "${CHEZ_HOME}/$1"
}

# chez_template <source-relpath> — render a source template (e.g. a script)
chez_template() {
  env -u CI HOME="${CHEZ_HOME}" chezmoi execute-template -S "${REPO_ROOT}" --no-tty < "${REPO_ROOT}/$1"
}

# Render a .chezmoiscripts template into a runnable bash script, so the package
# lists under test are the actual values from .chezmoidata.yaml. Echoes the path.
render_script_tmpl() {
  local src="$1" out
  out="${BATS_TEST_TMPDIR}/$(basename "$src" .tmpl)"
  [ -n "${CHEZ_HOME:-}" ] || chez_init test-host
  env -u CI HOME="${CHEZ_HOME}" chezmoi execute-template -S "${REPO_ROOT}" --no-tty < "$src" > "$out"
  chmod +x "$out"
  echo "$out"
}

# ---------------------------------------------------------------------------
# Output assertions
#
# Deliberately plain bash rather than bats-assert: the suite then has no
# vendored dependency and CI can run it with nothing but bats itself.
# ---------------------------------------------------------------------------

# True if $output contains the given line, matched whole
assert_line_in_output() {
  printf '%s\n' "$output" | grep -qxF "$1"
}

# True if $output contains a line matching the given ERE
assert_line_matches() {
  printf '%s\n' "$output" | grep -qE "$1"
}

# True if $output does NOT contain the given substring
refute_output_contains() {
  ! printf '%s\n' "$output" | grep -qF "$1"
}

# Create a fake but genuinely executable shell at the given path. It accepts
# `-c <cmd>` and exits 0, so it passes the script's exec smoke test.
make_fake_shell() {
  local path="$1"
  mkdir -p "$(dirname "$path")"
  printf '#!/bin/sh\nexit 0\n' > "$path"
  chmod +x "$path"
}
