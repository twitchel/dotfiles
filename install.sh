#!/usr/bin/env bash

echo_task() {
  printf "\033[0;34m--> %s\033[0m\n" "$*"
}

error() {
  printf "\033[0;31m%s\033[0m\n" "$*" >&2
  exit 1
}

# -e: exit on error
# -u: exit on unset variables
set -e

# Install Chezmoi if not already installed
if ! chezmoi="$(command -v chezmoi)"; then
  bin_dir="${HOME}/.local/bin"
  mkdir -p ${bin_dir}
  chezmoi="${bin_dir}/chezmoi"
  echo_task "Installing chezmoi to ${chezmoi}"
  if command -v curl >/dev/null; then
    chezmoi_installer="$(curl -fsSL https://git.io/chezmoi)"
  elif command -v wget >/dev/null; then
    chezmoi_installer="$(wget -qO- https://git.io/chezmoi)"
  else
    error "To install chezmoi, you must have curl or wget."
  fi
  sh -c "${chezmoi_installer}" -- -b "${bin_dir}"
  unset chezmoi_installer bin_dir
fi

chezmoi_args=""
chezmoi_init_args=""

if [ -n "${DOTFILES_DEBUG:-}" ]; then
  chezmoi_args="${chezmoi_args} --debug"
fi

if [ -n "${DOTFILES_VERBOSE:-}" ]; then
  chezmoi_args="${chezmoi_args} --verbose"
fi

if [ -n "${DOTFILES_NO_TTY:-}" ]; then
  chezmoi_args="${chezmoi_args} --no-tty"
fi

if [ -n "${DOTFILES_BRANCH:-}" ]; then
  echo_task "Chezmoi branch: ${DOTFILES_BRANCH}"
  chezmoi_init_args="${chezmoi_init_args} --branch ${DOTFILES_BRANCH}"
fi

# If DOTFILES_LOCAL_COPY is not set, we init from the main benrowe/dotfiles repository
if [ -n "${DOTFILES_REPOSITORY:-}" ]; then

  echo_task "Chezmoi repo: ${DOTFILES_REPOSITORY}"
  chezmoi_init_args="${chezmoi_init_args} ${DOTFILES_REPOSITORY}"
else

  echo_task "Chezmoi default repo: benrowe"
  chezmoi_init_args="${chezmoi_init_args} benrowe"
fi

echo_task "Running chezmoi init"
"${chezmoi}" init ${chezmoi_init_args} ${chezmoi_args}

echo_task "Running chezmoi apply"
"${chezmoi}" apply ${chezmoi_args}
