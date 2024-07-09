#!/usr/bin/env zsh

if [[ -z ${ZSH_SOURCED} ]]; then
  source ~/.zshrc
fi

if [ "${TERM:-}" = "" ]; then
  echo "Setting TERM to dumb" # makes tput happy in CI envs
  export TERM="dumb"
fi

# Run the tests
zunit --output-text
