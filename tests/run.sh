#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

check_dep() {
  local cmd="$1" install="$2"
  if ! command -v "$cmd" > /dev/null 2>&1; then
    echo "Missing: $cmd — install with: brew install $install" >&2
    exit 1
  fi
}

check_dep bats bats-core
check_dep yq yq

exec bats --recursive "${REPO_ROOT}/tests/bats" "$@"
