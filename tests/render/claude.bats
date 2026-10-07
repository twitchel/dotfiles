#!/usr/bin/env bats
# Render tier: the managed ~/.claude files (global CLAUDE.md, hooks, statusline)
# and the boundary of what chezmoi owns under ~/.claude.

load '../helpers/common'

@test ".claude/CLAUDE.md: renders the global instructions" {
  chez_init ci
  run chez_cat .claude/CLAUDE.md
  [ "$status" -eq 0 ]
  assert_line_in_output '# Code comments'
}

@test ".claude/hooks/herdr-agent-state.sh: renders a script with a shebang" {
  chez_init ci
  run chez_cat .claude/hooks/herdr-agent-state.sh
  [ "$status" -eq 0 ]
  [[ "${lines[0]}" == '#!'* ]]
}

@test "chezmoi managed: owns the claude files and no runtime paths" {
  chez_init ci
  run chez managed
  [ "$status" -eq 0 ]
  assert_line_in_output '.claude/CLAUDE.md'
  assert_line_in_output '.claude/hooks/herdr-agent-state.sh'
  assert_line_in_output '.claude/statusline-command.sh'
  ! assert_line_matches '^\.claude/(skills|projects|sessions)(/|$)'
}
