#!/usr/bin/env bash
# Shared helpers for the chezmoi BATS suite.
#
# The core trick: chezmoi's config template (home/.chezmoi.yaml.tmpl) uses
# promptStringOnce for customHostname/email, which opens /dev/tty directly and
# cannot be driven by --promptString on `init`. Instead we pre-seed an isolated
# chezmoi config with those answers so promptStringOnce finds them and skips the
# prompt, then run a normal `init` to materialise the full resolved data
# (hostname lowercasing, osid, BREWBIN, ...). After that, `chezmoi cat` and
# `chezmoi execute-template` render exactly as `apply` would.

load "${BATS_TEST_DIRNAME}/vendor/bats-support/load"
load "${BATS_TEST_DIRNAME}/vendor/bats-assert/load"

# Repo root = the directory containing .chezmoiroot (one level above test/).
REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"

# chez_init <hostname> [email]
# Sets up an isolated chezmoi HOME (under the per-test tmpdir) seeded with the
# prompt answers, then runs `chezmoi init`. Exports CHEZ_HOME for the helpers
# below. CI is unset so GitHub's CI=true does not pin the hostname to "ci".
chez_init() {
  local host="$1" email="${2:-test@example.com}"
  CHEZ_HOME="${BATS_TEST_TMPDIR}/home-${host}"
  mkdir -p "${CHEZ_HOME}/.config/chezmoi"
  cat > "${CHEZ_HOME}/.config/chezmoi/chezmoi.yaml" <<EOF
data:
  customHostname: ${host}
  email: ${email}
EOF
  env -u CI HOME="${CHEZ_HOME}" chezmoi init -S "${REPO_ROOT}" --no-tty
}

# chez() — run an arbitrary chezmoi subcommand against the isolated HOME.
chez() {
  env -u CI HOME="${CHEZ_HOME}" chezmoi "$@" -S "${REPO_ROOT}" --no-tty
}

# chez_cat <target-relpath>
# Render a managed target file (relative to HOME), e.g. .config/brew/Brewfile.
chez_cat() {
  chez cat "${CHEZ_HOME}/$1"
}

# chez_template <source-template-path>
# Render a source template (e.g. a .chezmoiscripts script) via execute-template,
# which resolves .hostData / .hostname / includes after chez_init has run.
chez_template() {
  env -u CI HOME="${CHEZ_HOME}" chezmoi execute-template -S "${REPO_ROOT}" --no-tty < "${REPO_ROOT}/$1"
}
