#!/usr/bin/env bats
# Unit tier: the aicli dispatcher and subcommands, run from the source tree against
# throwaway git repos with a local bare remote and a scripted gh.

load '../helpers/common'

setup() {
  setup_mocks
  export AICLI_LIB="${REPO_ROOT}/home/dot_local/lib/aicli"
  export AICLI_BIN="${BATS_TEST_TMPDIR}/bin/aicli"
  printf '#!/bin/bash\nexec bash "%s" "$@"\n' "${REPO_ROOT}/home/dot_local/bin/executable_aicli" > "$AICLI_BIN"
  chmod +x "$AICLI_BIN"

  export HOME="${BATS_TEST_TMPDIR}/home"
  export CLAUDE_CONFIG_DIR="${HOME}/.claude"
  mkdir -p "$CLAUDE_CONFIG_DIR"
  export GIT_CONFIG_NOSYSTEM=1
  git config --global user.name test
  git config --global user.email test@example.com
  git config --global init.defaultBranch main
}

# make_repo — a repo with one commit on main, pushed to a bare origin. cds into it.
make_repo() {
  git init -q --bare "${BATS_TEST_TMPDIR}/remote.git"
  git init -q "${BATS_TEST_TMPDIR}/repo"
  cd "${BATS_TEST_TMPDIR}/repo"
  git remote add origin "${BATS_TEST_TMPDIR}/remote.git"
  echo one > a.txt
  git add a.txt
  git commit -q -m "initial"
  git push -q -u origin main
  git remote set-head origin main
}

# mock_gh <existing-pr-url> — gh that reports an open PR at the URL (empty = none)
# and answers `pr create` with a fixed URL. Every call is logged.
mock_gh() {
  cat > "${BATS_TEST_TMPDIR}/bin/gh" <<SCRIPT
#!/bin/bash
echo "\$*" >> "${BATS_TEST_TMPDIR}/mock_gh.log"
case "\$1 \$2" in
  "pr view") [ -n "$1" ] && echo "$1" && exit 0; exit 1 ;;
  "pr create") echo "https://github.com/o/r/pull/9" ;;
  *) exit 1 ;;
esac
SCRIPT
  chmod +x "${BATS_TEST_TMPDIR}/bin/gh"
}

@test "aicli: no args prints the command list" {
  run aicli
  [ "$status" -eq 0 ]
  assert_line_matches '^  ctx '
  assert_line_matches '^  ship '
}

@test "aicli: unknown command exits 2" {
  run aicli nope
  [ "$status" -eq 2 ]
  assert_line_matches 'unknown command: nope'
}

@test "aicli ctx: reports branch, counts and stack" {
  make_repo
  git switch -q -c feat
  echo two >> a.txt
  git add a.txt
  touch go.mod new.txt
  run aicli ctx --no-pr
  [ "$status" -eq 0 ]
  assert_line_in_output 'branch: feat (default: main)'
  assert_line_in_output 'upstream: none'
  assert_line_in_output 'status: 1 staged, 0 modified, 2 untracked'
  assert_line_in_output 'stack: go'
}

@test "aicli ctx --json: upstream ahead count and commits" {
  make_repo
  echo two >> a.txt
  git commit -q -am second
  run aicli ctx --json --no-pr
  [ "$status" -eq 0 ]
  printf '%s' "$output" | jq -e '
    .branch == "main" and .upstream.ref == "origin/main" and .upstream.ahead == 1
    and (.commits | length) == 2 and .pr == null' > /dev/null
}

@test "aicli ship: refuses the default branch without -b" {
  make_repo
  echo two >> a.txt
  run aicli ship -a -m change
  [ "$status" -eq 1 ]
  assert_line_matches "on default branch 'main'"
  [ "$(git rev-list --count HEAD)" -eq 1 ]
}

@test "aicli ship: -b -a commits and pushes a new branch" {
  make_repo
  echo two >> a.txt
  touch b.txt
  run aicli ship -b feat -a -m "add b"
  [ "$status" -eq 0 ]
  assert_line_in_output 'branch: feat'
  [ "$(git -C "${BATS_TEST_TMPDIR}/remote.git" log -1 --format=%s feat)" = "add b" ]
  [ "$(git rev-parse --abbrev-ref '@{u}')" = "origin/feat" ]
  [ -z "$(git status --porcelain)" ]
}

@test "aicli ship: staged changes without -m fail" {
  make_repo
  git switch -q -c feat
  echo two >> a.txt
  git add a.txt
  run aicli ship
  [ "$status" -eq 1 ]
  assert_line_matches 'need a message'
}

@test "aicli ship: message from stdin" {
  make_repo
  git switch -q -c feat
  echo two >> a.txt
  run bash -c 'printf "from stdin\n\nbody line\n" | aicli ship -a -m -'
  [ "$status" -eq 0 ]
  [ "$(git log -1 --format=%B | head -n 1)" = "from stdin" ]
}

@test "aicli ship --pr: creates the PR with defaults from commits" {
  make_repo
  mock_gh ""
  git switch -q -c feat
  echo two >> a.txt
  git commit -q -am "first change"
  echo three >> a.txt
  run aicli ship -a -m "second change" --pr
  [ "$status" -eq 0 ]
  assert_line_in_output 'pr: https://github.com/o/r/pull/9'
  assert_mock_called_with gh 'pr create --base main --head feat --title first change --body - first change'
}

@test "aicli pr create: prints an existing open PR instead of creating" {
  make_repo
  mock_gh "https://github.com/o/r/pull/3"
  git switch -q -c feat
  git commit -q --allow-empty -m change
  git push -q -u origin feat
  run aicli pr create
  [ "$status" -eq 0 ]
  assert_line_in_output 'pr: https://github.com/o/r/pull/3 (existing)'
  ! grep -q 'pr create' "${BATS_TEST_TMPDIR}/mock_gh.log"
}

@test "aicli pr create: unpushed branch fails" {
  make_repo
  mock_gh ""
  git switch -q -c feat
  run aicli pr create
  [ "$status" -eq 1 ]
  assert_line_matches 'not pushed'
}

@test "aicli plugins list: enabled plugins with installed version" {
  mkdir -p "$CLAUDE_CONFIG_DIR/plugins"
  echo '{"enabledPlugins":{"a@m":true,"b@m":true,"c@m":false}}' > "$CLAUDE_CONFIG_DIR/settings.json"
  echo '{"version":2,"plugins":{"a@m":[{"version":"1.2.3","lastUpdated":"2026-01-02T00:00:00Z"}]}}' \
    > "$CLAUDE_CONFIG_DIR/plugins/installed_plugins.json"
  run aicli plugins list
  [ "$status" -eq 0 ]
  assert_line_matches '^a@m +1\.2\.3 2026-01-02$'
  assert_line_matches '^b@m +not-installed'
  refute_output_contains 'c@m'
}

@test "aicli plugins sync: adds the marketplace from settings and installs" {
  mock claude
  mkdir -p "$CLAUDE_CONFIG_DIR/plugins"
  echo '{"enabledPlugins":{"p@mp":true},"extraKnownMarketplaces":{"mp":{"source":{"source":"github","repo":"o/r"}}}}' \
    > "$CLAUDE_CONFIG_DIR/settings.json"
  echo '{}' > "$CLAUDE_CONFIG_DIR/plugins/known_marketplaces.json"
  run aicli plugins sync
  [ "$status" -eq 0 ]
  assert_mock_called_with claude 'plugin marketplace add o/r'
  assert_mock_called_with claude 'plugin install p@mp'
}

@test "aicli doctor: warns about enabled plugins that are not installed" {
  mock gh 1
  mock claude 0 "9.9.9"
  mock chezmoi
  echo '{"enabledPlugins":{"x@m":true}}' > "$CLAUDE_CONFIG_DIR/settings.json"
  run env -u ANTHROPIC_BASE_URL aicli doctor
  [ "$status" -eq 0 ]
  assert_line_matches '^warn gh not authenticated'
  assert_line_matches '^warn enabled but not installed: x@m'
  assert_line_matches '^ok   claude 9\.9\.9'
}
