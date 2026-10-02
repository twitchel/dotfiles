#!/usr/bin/env bats
# Render tier: the generated zsh bootstrap config.

load '../helpers/common'

@test "bootstrap.zshrc: Homebrew shellenv uses the per-OS BREWBIN path" {
  chez_init ci
  run chez_cat .config/zsh/bootstrap.zshrc
  [ "$status" -eq 0 ]
  # BREWBIN is set per-OS in .chezmoi.yaml.tmpl, so assert the path for the host
  # actually running the suite — this runs on both Linux containers and macOS.
  if [ "$(uname -s)" = "Darwin" ]; then
    assert_line_in_output 'eval "$(/opt/homebrew/bin/brew shellenv)"'
  else
    assert_line_in_output 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"'
  fi
}

@test "bootstrap.zshrc: prepends ~/.local/bin to PATH" {
  chez_init ci
  run chez_cat .config/zsh/bootstrap.zshrc
  [ "$status" -eq 0 ]
  assert_line_in_output 'export PATH="$HOME/.local/bin:$PATH"'
}

@test "bootstrap.zshrc: ssh-agent only starts without an existing agent, silenced" {
  chez_init ci
  run chez_cat .config/zsh/bootstrap.zshrc
  [ "$status" -eq 0 ]
  assert_line_in_output 'if [ -z "$SSH_AUTH_SOCK" ] && command -v ssh-agent > /dev/null; then'
  assert_line_in_output '  eval "$(ssh-agent)" > /dev/null'
}

@test ".zshrc: sources functions.zshrc" {
  chez_init ci
  run chez_cat .config/zsh/.zshrc
  [ "$status" -eq 0 ]
  assert_line_in_output 'source_file "$ZDOTDIR/functions.zshrc"'
}

@test "functions.zshrc: serve mounts \$PWD read-only at the nginx webroot" {
  chez_init ci
  run chez_cat .config/zsh/functions.zshrc
  [ "$status" -eq 0 ]
  assert_line_matches '\-\-volume "\$PWD:/usr/share/nginx/html:ro"'
  # Relabelling the served directory (:z) would outlive the container.
  assert_line_matches '\-\-security-opt label=disable'
}

@test "functions.zshrc: serve publishes to localhost unless -a is given" {
  chez_init ci
  run chez_cat .config/zsh/functions.zshrc
  [ "$status" -eq 0 ]
  assert_line_in_output '  local publish="127.0.0.1:$port:80"'
  assert_line_in_output '  (( all )) && publish="$port:80"'
}

@test "functions.zshrc: defines the worktree functions when sourced in zsh" {
  chez_init ci
  # Render both files into a scratch ZDOTDIR, then source from a different
  # cwd so a $PWD-relative path to worktrees.functions.zshrc can't pass.
  local zdotdir="${BATS_TEST_TMPDIR}/zdotdir"
  mkdir -p "$zdotdir"
  chez_cat .config/zsh/functions.zshrc > "$zdotdir/functions.zshrc"
  chez_cat .config/zsh/worktrees.functions.zshrc > "$zdotdir/worktrees.functions.zshrc"

  run env ZDOTDIR="$zdotdir" zsh -f -c '
    cd /
    source "$ZDOTDIR/functions.zshrc" || exit 1
    for f in wtdir wt wtr wtrm wtl wtcd wtprune; do
      [[ $(whence -w $f) == "$f: function" ]] || { echo "missing: $f"; exit 1; }
    done' 2>&1
  [ "$status" -eq 0 ] || { echo "$output"; false; }
  [ -z "$output" ]
}
