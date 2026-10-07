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
  if assert_line_matches '^\.claude/(skills|projects|sessions)(/|$)'; then false; fi
}

# Seed the isolated destination's settings.json with the given JSON.
seed_settings() {
  mkdir -p "${CHEZ_HOME}/.claude"
  printf '%s\n' "$1" > "${CHEZ_HOME}/.claude/settings.json"
}

@test ".claude/settings.json: no existing file renders the managed fragment" {
  chez_init ci
  run chez_cat .claude/settings.json
  [ "$status" -eq 0 ]
  printf '%s' "$output" | jq -e '
    .model == "opus[1m]"
    and .statusLine.command == "bash \"$HOME/.claude/statusline-command.sh\""
    and .statusLine.refreshInterval == 2
    and .hooks.SessionStart[0].hooks[0].command == "bash \"$HOME/.claude/hooks/herdr-agent-state.sh\" session"
    and .hooks.SessionStart[0].hooks[0].timeout == 10
    and .enabledPlugins["superpowers@claude-plugins-official"] == true
    and (has("permissions") | not)' > /dev/null
}

@test ".claude/settings.json: managed keys win and unmanaged live keys survive" {
  chez_init ci
  seed_settings '{"model":"sonnet","theme":"dark","tui":"fullscreen","autoMode":{"soft_deny":["x"]},"enabledPlugins":{"foo@bar":false}}'
  run chez_cat .claude/settings.json
  [ "$status" -eq 0 ]
  printf '%s' "$output" | jq -e '
    .model == "opus[1m]"
    and .theme == "dark"
    and .tui == "fullscreen"
    and .autoMode.soft_deny == ["x"]
    and .enabledPlugins["foo@bar"] == false
    and .enabledPlugins["superpowers@claude-plugins-official"] == true' > /dev/null
}

@test ".claude/settings.json: extra hook events survive and SessionStart is managed" {
  chez_init ci
  seed_settings '{"hooks":{"Stop":[{"hooks":[{"type":"command","command":"echo done"}]}],"SessionStart":[{"matcher":"old","hooks":[]}]}}'
  run chez_cat .claude/settings.json
  [ "$status" -eq 0 ]
  printf '%s' "$output" | jq -e '
    .hooks.Stop[0].hooks[0].command == "echo done"
    and (.hooks.SessionStart | length) == 1
    and .hooks.SessionStart[0].matcher == "^(startup|resume|clear|compact|fork)$"
    and .hooks.SessionStart[0].hooks[0].timeout == 10' > /dev/null
}

@test ".claude/settings.json: numbers and special characters survive the merge" {
  chez_init ci
  seed_settings '{"count":10,"ratio":0.5,"note":"a<b&c"}'
  run chez_cat .claude/settings.json
  [ "$status" -eq 0 ]
  printf '%s' "$output" | jq -e '.count == 10 and .ratio == 0.5 and .note == "a<b&c"' > /dev/null
  assert_line_matches '"count": 10,?$'
  assert_line_matches '"refreshInterval": 2,?$'
}

@test ".claude/settings.json: output ends in exactly one newline" {
  chez_init ci
  chez_cat .claude/settings.json > "${BATS_TEST_TMPDIR}/out"
  [ "$(tail -c 2 "${BATS_TEST_TMPDIR}/out" | xxd -p)" = "7d0a" ]
}
