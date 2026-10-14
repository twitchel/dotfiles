#!/usr/bin/env bats
# Unit tier: the delegate-guard hook, run from the source tree with the config and temp
# dirs pointed at fixed fake paths (a real temp dir could itself sit under /tmp).

load '../helpers/common'

setup() {
  GUARD="${REPO_ROOT}/home/dot_claude/hooks/executable_delegate-guard.sh"
  export CLAUDE_CONFIG_DIR=/opt/fake/claude
  export TMPDIR=/opt/fake/tmp
  unset CLAUDE_INLINE_EDITS
}

# pre_tool <json> — run the guard in pre-tool mode with the JSON on stdin.
pre_tool() {
  run bash "$GUARD" pre-tool <<< "$1"
}

assert_denied() {
  [ "$status" -eq 0 ]
  printf '%s' "$output" | jq -e '.hookSpecificOutput.permissionDecision == "deny"' > /dev/null
}

assert_allowed() {
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "delegate-guard: main-session Write to a project path is denied" {
  pre_tool '{"tool_name":"Write","tool_input":{"file_path":"/work/proj/a.txt"}}'
  assert_denied
  printf '%s' "$output" | jq -e '.hookSpecificOutput.hookEventName == "PreToolUse"' > /dev/null
}

@test "delegate-guard: Edit without a notebook_path is denied" {
  pre_tool '{"tool_name":"Edit","tool_input":{"file_path":"/work/proj/a.txt","old_string":"a","new_string":"b"}}'
  assert_denied
}

@test "delegate-guard: NotebookEdit via notebook_path is denied" {
  pre_tool '{"tool_name":"NotebookEdit","tool_input":{"notebook_path":"/work/proj/n.ipynb"}}'
  assert_denied
}

@test "delegate-guard: a subagent call is allowed" {
  pre_tool '{"agent_id":"abc123","agent_type":"writer-quick","tool_input":{"file_path":"/work/proj/a.txt"}}'
  assert_allowed
}

@test "delegate-guard: a path under the config dir is allowed" {
  pre_tool '{"tool_input":{"file_path":"/opt/fake/claude/projects/m/MEMORY.md"}}'
  assert_allowed
}

@test "delegate-guard: a path under TMPDIR is allowed" {
  pre_tool '{"tool_input":{"file_path":"/opt/fake/tmp/scratch.txt"}}'
  assert_allowed
}

@test "delegate-guard: /tmp and /private/tmp are allowed" {
  pre_tool '{"tool_input":{"file_path":"/tmp/x"}}'
  assert_allowed
  pre_tool '{"tool_input":{"file_path":"/private/tmp/x"}}'
  assert_allowed
}

@test "delegate-guard: a sibling sharing the prefix string is denied" {
  pre_tool '{"tool_input":{"file_path":"/opt/fake/claude-other/x"}}'
  assert_denied
  pre_tool '{"tool_input":{"file_path":"/tmpfoo/x"}}'
  assert_denied
}

@test "delegate-guard: CLAUDE_INLINE_EDITS=1 allows" {
  CLAUDE_INLINE_EDITS=1 pre_tool '{"tool_input":{"file_path":"/work/proj/a.txt"}}'
  assert_allowed
}

@test "delegate-guard: the inline-edits toggle file allows" {
  export CLAUDE_CONFIG_DIR="${BATS_TEST_TMPDIR}/claude"
  mkdir -p "$CLAUDE_CONFIG_DIR"
  touch "${CLAUDE_CONFIG_DIR}/inline-edits"
  pre_tool '{"tool_input":{"file_path":"/work/proj/a.txt"}}'
  assert_allowed
}

@test "delegate-guard: the deny reason does not reveal the bypass" {
  pre_tool '{"tool_input":{"file_path":"/work/proj/a.txt"}}'
  assert_denied
  refute_output_contains 'inline-edits'
  refute_output_contains 'CLAUDE_INLINE_EDITS'
}

@test "delegate-guard: prompt mode prints the reminder" {
  run bash "$GUARD" prompt < /dev/null
  [ "$status" -eq 0 ]
  assert_line_in_output 'Delegation: file edits go to writer-quick / writer / writer-deep (main-session Edit/Write on project files is blocked); multi-file searches, flow tracing and reviews go to reader-quick / reader / reader-deep. Single-fact lookups in a known file may stay inline.'
}

@test "delegate-guard: prompt mode is silent with the toggle file present" {
  export CLAUDE_CONFIG_DIR="${BATS_TEST_TMPDIR}/claude"
  mkdir -p "$CLAUDE_CONFIG_DIR"
  touch "${CLAUDE_CONFIG_DIR}/inline-edits"
  run bash "$GUARD" prompt < /dev/null
  assert_allowed
}

@test "delegate-guard: an unknown mode exits 0" {
  run bash "$GUARD" bogus < /dev/null
  [ "$status" -eq 0 ]
  run bash "$GUARD" < /dev/null
  [ "$status" -eq 0 ]
}

# agent <session> [type] — run the guard in agent mode for one spawn.
agent() {
  run bash "$GUARD" agent <<< "{\"session_id\":\"$1\",\"tool_input\":{\"subagent_type\":\"${2:-reader}\"}}"
}

# spawn_n <n> <session> [type] — n sequential spawns, all expected allowed.
spawn_n() {
  local i
  for ((i = 0; i < $1; i++)); do
    agent "$2" "${3:-reader}"
    assert_allowed
  done
}

agent_setup() {
  export TMPDIR="${BATS_TEST_TMPDIR}/tmp"
  unset CLAUDE_AGENT_CAP CLAUDE_DEEP_CAP
}

@test "delegate-guard: agent mode allows 8 spawns and denies the 9th" {
  agent_setup
  spawn_n 8 s1
  agent s1
  assert_denied
  printf '%s' "$output" | jq -e '.hookSpecificOutput.permissionDecisionReason | startswith("Agent budget for this prompt is used up (8 spawns)")' > /dev/null
}

@test "delegate-guard: agent mode caps deep agents at 2 but still allows others" {
  agent_setup
  spawn_n 2 s1 reader-deep
  agent s1 writer-deep
  assert_denied
  printf '%s' "$output" | jq -e '.hookSpecificOutput.permissionDecisionReason | startswith("Deep-agent budget for this prompt is used up (2 ")' > /dev/null
  agent s1 reader
  assert_allowed
}

@test "delegate-guard: CLAUDE_AGENT_CAP lowers the cap" {
  agent_setup
  export CLAUDE_AGENT_CAP=3
  spawn_n 3 s1
  agent s1
  assert_denied
}

@test "delegate-guard: CLAUDE_AGENT_CAP=0 is unlimited" {
  agent_setup
  export CLAUDE_AGENT_CAP=0
  spawn_n 20 s1
}

@test "delegate-guard: a non-numeric cap falls back to the default" {
  agent_setup
  export CLAUDE_AGENT_CAP=lots
  spawn_n 8 s1
  agent s1
  assert_denied
}

@test "delegate-guard: prompt mode resets the agent budget" {
  agent_setup
  spawn_n 8 s1
  agent s1
  assert_denied
  run bash "$GUARD" prompt <<< '{"session_id":"s1"}'
  [ "$status" -eq 0 ]
  agent s1
  assert_allowed
}

@test "delegate-guard: prompt mode resets the budget even with the edit bypass" {
  agent_setup
  spawn_n 8 s1
  CLAUDE_INLINE_EDITS=1 run bash "$GUARD" prompt <<< '{"session_id":"s1"}'
  assert_allowed
  agent s1
  assert_allowed
}

@test "delegate-guard: agent budgets are per session" {
  agent_setup
  spawn_n 8 s1
  agent s2
  assert_allowed
}

@test "delegate-guard: the edit bypass does not lift the agent cap" {
  agent_setup
  export CLAUDE_INLINE_EDITS=1
  spawn_n 8 s1
  agent s1
  assert_denied
}

@test "delegate-guard: concurrent agent calls allow exactly the cap" {
  agent_setup
  local i allowed=0 denied=0 f
  for i in $(seq 1 12); do
    bash "$GUARD" agent > "${BATS_TEST_TMPDIR}/out.$i" <<< '{"session_id":"par","tool_input":{"subagent_type":"reader"}}' &
  done
  wait
  for i in $(seq 1 12); do
    f="${BATS_TEST_TMPDIR}/out.$i"
    if [ -s "$f" ]; then denied=$((denied + 1)); else allowed=$((allowed + 1)); fi
  done
  [ "$allowed" -eq 8 ]
  [ "$denied" -eq 4 ]
}

@test "delegate-guard: a session_id with path characters stays inside the budget dir" {
  agent_setup
  agent '../../evil/x' reader
  assert_allowed
  [ -f "${TMPDIR}/claude-agent-budget/evilx" ]
  [ ! -e "${TMPDIR}/evil" ]
}

@test "delegate-guard: an empty session_id writes nothing" {
  agent_setup
  agent '' reader
  assert_allowed
  [ ! -e "${TMPDIR}/claude-agent-budget" ]
}

@test "delegate-guard: agent deny text does not name the env vars" {
  agent_setup
  spawn_n 2 s1 reader-deep
  agent s1 reader-deep
  refute_output_contains 'CLAUDE_DEEP_CAP'
  refute_output_contains 'CLAUDE_AGENT_CAP'
  export CLAUDE_AGENT_CAP=1
  agent s2
  agent s2
  refute_output_contains 'CLAUDE_AGENT_CAP'
}
