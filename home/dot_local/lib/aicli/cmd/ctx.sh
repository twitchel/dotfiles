# shellcheck shell=bash
# summary: repo snapshot: branch, upstream, status, diffstat, recent commits, PR, stack
# usage: aicli ctx [--json] [--no-pr] [-n <commits>]
#
#   --json      machine-readable output
#   --no-pr     skip the GitHub PR lookup (network)
#   -n N        recent commits to show (default 5)

# Status lines listed before truncating.
CTX_FILE_CAP=20

ctx_stack() {
  local root="$1" out="" pm targets
  [ -f "$root/go.mod" ] && out="$out go"
  if [ -f "$root/package.json" ]; then
    pm=npm
    [ -f "$root/pnpm-lock.yaml" ] && pm=pnpm
    [ -f "$root/yarn.lock" ] && pm=yarn
    { [ -f "$root/bun.lockb" ] || [ -f "$root/bun.lock" ]; } && pm=bun
    out="$out node($pm)"
  fi
  [ -f "$root/pyproject.toml" ] && out="$out python"
  [ -f "$root/Cargo.toml" ] && out="$out rust"
  { [ -f "$root/justfile" ] || [ -f "$root/Justfile" ]; } && out="$out just"
  if [ -f "$root/Makefile" ]; then
    targets=$(grep -oE '^[A-Za-z0-9][A-Za-z0-9_.-]*:' "$root/Makefile" | tr -d : | sort -u | tr '\n' ',')
    out="$out make[${targets%,}]"
  fi
  [ -n "$(find "$root" -name '*.bats' -not -path '*/node_modules/*' -not -path '*/vendor/*' -print -quit 2> /dev/null)" ] && out="$out bats"
  [ -f "$root/.chezmoiroot" ] && out="$out chezmoi"
  echo "${out# }"
}

main() {
  local json=false want_pr=true n=5
  while [ $# -gt 0 ]; do
    case "$1" in
      --json) json=true ;;
      --no-pr) want_pr=false ;;
      -n) n="${2:?-n needs a number}"; shift ;;
      -h | --help) usage_from "$AICLI_LIB/cmd/ctx.sh"; return 0 ;;
      *) die "ctx: unknown argument: $1" ;;
    esac
    shift
  done
  need git
  in_repo
  $json && need jq

  local root branch def upstream="" ahead=0 behind=0 porcelain
  root=$(git rev-parse --show-toplevel)
  branch=$(current_branch)
  def=$(default_branch)
  if upstream=$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2> /dev/null); then
    read -r behind ahead <<< "$(git rev-list --left-right --count '@{u}...HEAD')"
  else
    upstream=""
  fi

  porcelain=$(git status --porcelain=v1)
  local staged modified untracked
  staged=$(printf '%s\n' "$porcelain" | grep -c '^[MADRCU]' || true)
  modified=$(printf '%s\n' "$porcelain" | grep -c '^.[MDU]' || true)
  untracked=$(printf '%s\n' "$porcelain" | grep -c '^??' || true)

  local staged_stat unstaged_stat commits=""
  staged_stat=$(git diff --cached --shortstat | sed 's/^ //')
  unstaged_stat=$(git diff --shortstat | sed 's/^ //')
  has_commits && commits=$(git log -n "$n" --format='%h %s (%cr)')

  local pr=""
  if $want_pr && [ "$branch" != HEAD ] && command -v gh > /dev/null 2>&1; then
    pr=$(gh pr view --json number,state,isDraft,url \
      -q '"#\(.number) \(.state)\(if .isDraft then " draft" else "" end) \(.url)"' 2> /dev/null || true)
  fi

  local stack
  stack=$(ctx_stack "$root")

  if $json; then
    jq -n \
      --arg root "$root" --arg branch "$branch" --arg default "$def" \
      --arg upstream "$upstream" --argjson ahead "$ahead" --argjson behind "$behind" \
      --argjson staged "$staged" --argjson modified "$modified" --argjson untracked "$untracked" \
      --arg files "$porcelain" --arg staged_stat "$staged_stat" --arg unstaged_stat "$unstaged_stat" \
      --arg commits "$commits" --arg pr "$pr" --arg stack "$stack" '
      def lines: split("\n") | map(select(length > 0));
      {root: $root, branch: $branch, default_branch: $default,
       upstream: (if $upstream == "" then null else {ref: $upstream, ahead: $ahead, behind: $behind} end),
       status: {staged: $staged, modified: $modified, untracked: $untracked, files: ($files | lines)},
       diffstat: {staged: $staged_stat, unstaged: $unstaged_stat},
       commits: ($commits | lines),
       pr: (if $pr == "" then null else $pr end),
       stack: ($stack | split(" ") | map(select(length > 0)))}'
    return 0
  fi

  echo "repo: $root"
  echo "branch: $branch (default: $def)"
  if [ -n "$upstream" ]; then
    echo "upstream: $upstream, ahead $ahead, behind $behind"
  else
    echo "upstream: none"
  fi
  echo "status: $staged staged, $modified modified, $untracked untracked"
  if [ -n "$porcelain" ]; then
    printf '%s\n' "$porcelain" | head -n "$CTX_FILE_CAP" | sed 's/^/  /'
    local total
    total=$(printf '%s\n' "$porcelain" | wc -l | tr -d ' ')
    [ "$total" -gt "$CTX_FILE_CAP" ] && echo "  ... $((total - CTX_FILE_CAP)) more"
  fi
  [ -n "$staged_stat" ] && echo "staged: $staged_stat"
  [ -n "$unstaged_stat" ] && echo "unstaged: $unstaged_stat"
  if [ -n "$commits" ]; then
    echo "commits:"
    printf '%s\n' "$commits" | sed 's/^/  /'
  fi
  [ -n "$pr" ] && echo "pr: $pr"
  [ -n "$stack" ] && echo "stack: $stack"
  return 0
}
