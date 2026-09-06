#!/usr/bin/env sh
# Bootstrap run inside a RAW distro container by `make ci-{fedora,ubuntu}` to
# reproduce the GitHub Actions build on a fresh machine: install deps + chezmoi,
# then run the same init/data/apply steps CI runs (via `make ci-native`).
set -e

if command -v dnf >/dev/null 2>&1; then
  dnf install -y git curl make >/dev/null
elif command -v apt-get >/dev/null 2>&1; then
  apt-get update >/dev/null
  DEBIAN_FRONTEND=noninteractive apt-get install -y git curl make >/dev/null
else
  echo "unsupported base image: no dnf or apt-get" >&2
  exit 1
fi

sh -c "$(curl -fsLS get.chezmoi.io)" -- -b /usr/local/bin

make ci-native
