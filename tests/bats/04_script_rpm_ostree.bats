#!/usr/bin/env bats
# Tests for run_onchange_after_040_rpm-ostree.sh.tmpl
# This script uses {{ range }} template vars for package names.
# Tests exercise the bash logic inline to avoid needing chezmoi rendering.

load '../helpers/common'

setup() {
  setup_mocks
}

# Helper: run the "skip if no rpm-ostree" guard logic
_guard_no_rpm_ostree() {
  bash <<'SCRIPT'
if ! command -v rpm-ostree >/dev/null 2>&1; then
  echo "No rpm-ostree on system, skipping"
  exit 0
fi
echo "rpm-ostree found"
SCRIPT
}

@test "skips when rpm-ostree is not installed" {
  # No rpm-ostree mock in PATH
  run _guard_no_rpm_ostree
  [ "$status" -eq 0 ]
  [[ "$output" == *"No rpm-ostree"* ]]
}

@test "continues when rpm-ostree is installed" {
  mock rpm-ostree 0

  run _guard_no_rpm_ostree
  [ "$status" -eq 0 ]
  [[ "$output" == *"rpm-ostree found"* ]]
}

@test "skips adding Ghostty COPR when repo file already exists" {
  mock curl 0
  local copr_file="${BATS_TEST_TMPDIR}/ghostty.repo"
  touch "$copr_file"

  run bash <<SCRIPT
GHOSTTY_COPR="${copr_file}"
if [ ! -f "\$GHOSTTY_COPR" ]; then
  curl -fsSL "https://example.com/ghostty.repo" | sudo tee "\$GHOSTTY_COPR" > /dev/null
  echo "added copr"
else
  echo "copr already present"
fi
SCRIPT

  [ "$status" -eq 0 ]
  [[ "$output" == *"copr already present"* ]]
  assert_mock_not_called curl
}

@test "adds Ghostty COPR when repo file is absent" {
  mock curl 0
  mock sudo 0
  local copr_file="${BATS_TEST_TMPDIR}/ghostty.repo"

  run bash <<SCRIPT
GHOSTTY_COPR="${copr_file}"
if [ ! -f "\$GHOSTTY_COPR" ]; then
  echo "adding copr"
  curl -fsSL "https://example.com/ghostty.repo" > /dev/null
else
  echo "copr already present"
fi
SCRIPT

  [ "$status" -eq 0 ]
  [[ "$output" == *"adding copr"* ]]
  assert_mock_called curl
}

@test "excludes already-installed packages from install list" {
  # rpm -q returns 0 (package is installed)
  mock rpm 0

  run bash <<'SCRIPT'
PACKAGES_TO_INSTALL=()
for pkg in "ghostty" "zsh"; do
  if ! rpm -q "$pkg" > /dev/null 2>&1; then
    PACKAGES_TO_INSTALL+=("$pkg")
  fi
done
echo "count:${#PACKAGES_TO_INSTALL[@]}"
SCRIPT

  [ "$status" -eq 0 ]
  [[ "$output" == *"count:0"* ]]
}

@test "includes packages that are not yet installed" {
  # rpm -q returns 1 (package not installed)
  mock rpm 1

  run bash <<'SCRIPT'
PACKAGES_TO_INSTALL=()
for pkg in "ghostty" "zsh"; do
  if ! rpm -q "$pkg" > /dev/null 2>&1; then
    PACKAGES_TO_INSTALL+=("$pkg")
  fi
done
echo "count:${#PACKAGES_TO_INSTALL[@]}"
SCRIPT

  [ "$status" -eq 0 ]
  [[ "$output" == *"count:2"* ]]
}

@test "skips rpm-ostree install when all packages already installed" {
  mock rpm 0
  mock rpm-ostree 0

  run bash <<'SCRIPT'
PACKAGES_TO_INSTALL=()
for pkg in "ghostty" "zsh"; do
  if ! rpm -q "$pkg" > /dev/null 2>&1; then
    PACKAGES_TO_INSTALL+=("$pkg")
  fi
done
if [ ${#PACKAGES_TO_INSTALL[@]} -eq 0 ]; then
  echo "All rpm-ostree packages already installed"
  exit 0
fi
rpm-ostree install "${PACKAGES_TO_INSTALL[@]}"
SCRIPT

  [ "$status" -eq 0 ]
  [[ "$output" == *"already installed"* ]]
  assert_mock_not_called rpm-ostree
}

@test "runs rpm-ostree install when packages are missing" {
  # rpm returns 1 (not installed) for all queries
  mock rpm 1
  mock rpm-ostree 0

  run bash <<'SCRIPT'
PACKAGES_TO_INSTALL=()
for pkg in "ghostty" "zsh"; do
  if ! rpm -q "$pkg" > /dev/null 2>&1; then
    PACKAGES_TO_INSTALL+=("$pkg")
  fi
done
if [ ${#PACKAGES_TO_INSTALL[@]} -eq 0 ]; then
  echo "all installed"
  exit 0
fi
rpm-ostree install "${PACKAGES_TO_INSTALL[@]}"
SCRIPT

  [ "$status" -eq 0 ]
  assert_mock_called rpm-ostree
  assert_mock_called_with rpm-ostree "ghostty"
  assert_mock_called_with rpm-ostree "zsh"
}

@test "packages installed in a single rpm-ostree call" {
  mock rpm 1
  mock rpm-ostree 0

  run bash <<'SCRIPT'
PACKAGES_TO_INSTALL=()
for pkg in "ghostty" "zsh"; do
  if ! rpm -q "$pkg" > /dev/null 2>&1; then
    PACKAGES_TO_INSTALL+=("$pkg")
  fi
done
[ ${#PACKAGES_TO_INSTALL[@]} -gt 0 ] && rpm-ostree install "${PACKAGES_TO_INSTALL[@]}"
SCRIPT

  [ "$status" -eq 0 ]
  # Only one line in the log = single call
  local log="${BATS_TEST_TMPDIR}/mock_rpm-ostree.log"
  [ "$(wc -l < "$log")" -eq 1 ]
}
