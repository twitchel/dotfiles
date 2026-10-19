#!/usr/bin/env bats
# Render tier: the managed ~/.claude files (global CLAUDE.md, hooks, statusline, settings.json)
# and the boundary of what chezmoi owns under ~/.claude.

load '../helpers/common'

@test ".claude/CLAUDE.md: renders the global instructions" {
  chez_init ci
  run chez_cat .claude/CLAUDE.md
  [ "$status" -eq 0 ]
  assert_line_in_output '# Writing style: ASD-STE100'
  assert_line_in_output '# Code comments'
}

@test ".claude/hooks/herdr-agent-state.sh: renders a script with a shebang" {
  chez_init ci
  run chez_cat .claude/hooks/herdr-agent-state.sh
  [ "$status" -eq 0 ]
  [[ "${lines[0]}" == '#!'* ]]
}

@test ".claude/hooks/delegate-guard.sh: managed (executable_ source), renders a script with a shebang" {
  chez_init ci
  run chez managed --include files
  assert_line_in_output '.claude/hooks/delegate-guard.sh'
  run chez_cat .claude/hooks/delegate-guard.sh
  [ "$status" -eq 0 ]
  [[ "${lines[0]}" == '#!'* ]]
  [ -f "${REPO_ROOT}/home/dot_claude/hooks/executable_delegate-guard.sh" ]
}

@test "chezmoi managed: owns the claude files and no runtime paths" {
  chez_init ci
  run chez managed
  [ "$status" -eq 0 ]
  assert_line_in_output '.claude/CLAUDE.md'
  assert_line_in_output '.claude/hooks/herdr-agent-state.sh'
  assert_line_in_output '.claude/statusline-command.sh'
  assert_line_in_output '.claude/skills/verification-before-completion/SKILL.md'
  if assert_line_in_output '.claude/skills/SOURCES.md'; then false; fi
  if assert_line_matches '^\.claude/(skills/(synced|presenterm)|projects|sessions)(/|$)'; then false; fi
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
    and .hooks.PreToolUse[0].matcher == "^(Edit|Write|MultiEdit|NotebookEdit)$"
    and .hooks.PreToolUse[0].hooks[0].command == "bash \"$HOME/.claude/hooks/delegate-guard.sh\" pre-tool"
    and .hooks.PreToolUse[1].matcher == "^(Agent|Task)$"
    and .hooks.PreToolUse[1].hooks[0].command == "bash \"$HOME/.claude/hooks/delegate-guard.sh\" agent"
    and .hooks.PreToolUse[1].hooks[0].timeout == 5
    and .hooks.UserPromptSubmit[0].hooks[0].command == "bash \"$HOME/.claude/hooks/delegate-guard.sh\" prompt"
    and .enabledPlugins["superpowers@claude-plugins-official"] == false
    and .enabledPlugins["mattpocock-skills@claude-plugins-official"] == false
    and .enabledPlugins["mattpocock-skills@mattpocock"] == true
    and .extraKnownMarketplaces.mattpocock.source.repo == "mattpocock/skills"
    and .extraKnownMarketplaces.mattpocock.autoUpdate == true
    and (.permissions.allow | index("Bash(aicli ctx:*)") != null)' > /dev/null
}

@test ".claude/settings.json: live marketplaces survive alongside the managed one" {
  chez_init ci
  seed_settings '{"extraKnownMarketplaces":{"caveman":{"source":{"source":"github","repo":"JuliusBrussee/caveman"}}}}'
  run chez_cat .claude/settings.json
  [ "$status" -eq 0 ]
  printf '%s' "$output" | jq -e '
    .extraKnownMarketplaces.caveman.source.repo == "JuliusBrussee/caveman"
    and .extraKnownMarketplaces.mattpocock.source.repo == "mattpocock/skills"' > /dev/null
}

@test ".claude/agents: six reader/writer agents with model and effort tiers" {
  chez_init ci
  local spec name model effort
  for spec in reader-quick:haiku:low reader:sonnet:medium reader-deep:opus:high \
    writer-quick:haiku:low writer:sonnet:medium writer-deep:opus:high; do
    IFS=: read -r name model effort <<< "$spec"
    run chez_cat ".claude/agents/${name}.md"
    [ "$status" -eq 0 ]
    [ "$(printf '%s\n' "$output" | yq --front-matter=extract '.name + " " + .model + " " + .effort')" = "$name $model $effort" ]
  done
}

@test ".claude/agents: readers have no edit tools; writer-quick has no shell" {
  chez_init ci
  local name
  for name in reader-quick reader reader-deep; do
    run chez_cat ".claude/agents/${name}.md"
    refute_output_contains 'Edit'
    refute_output_contains 'Write,'
  done
  run chez_cat .claude/agents/writer-quick.md
  [ "$(printf '%s\n' "$output" | yq --front-matter=extract '.tools')" = "Read, Edit, Write, Grep, Glob" ]
}

@test ".claude/skills: vendored skills carry no superpowers: plugin references" {
  run grep -rn 'superpowers:' "${REPO_ROOT}/home/dot_claude/skills"
  [ "$status" -eq 1 ]
}

@test ".claude/skills: subagent-driven-development scripts install executable" {
  chez_init ci
  run chez managed --include files
  assert_line_in_output '.claude/skills/subagent-driven-development/scripts/sdd-workspace'
  assert_line_in_output '.claude/skills/subagent-driven-development/final-reviewer-prompt.md'
}

@test "aicli: dispatcher and every subcommand are managed" {
  chez_init ci
  run chez managed --include files
  assert_line_in_output '.local/bin/aicli'
  local cmd
  for cmd in ctx ship pr doctor plugins; do
    assert_line_in_output ".local/lib/aicli/cmd/${cmd}.sh"
  done
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
    and .enabledPlugins["superpowers@claude-plugins-official"] == false' > /dev/null
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
  [ "$(tail -c 2 "${BATS_TEST_TMPDIR}/out" | od -An -tx1 | tr -d ' \n')" = "7d0a" ]
}
