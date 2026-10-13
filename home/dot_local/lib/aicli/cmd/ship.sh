# summary: commit (optional), push the branch, optionally open a PR
# usage: aicli ship [-m <msg>|-m -] [-a] [-b <branch>] [--pr] [--draft]
#
#   -m MSG      commit message; "-" reads it from stdin. Required when there is anything to commit
#   -a          stage everything first (tracked and untracked)
#   -b BRANCH   create and switch to BRANCH before committing
#   --pr        then run `aicli pr create`
#   --draft     with --pr, open as draft
#
#   Refuses to commit or push on the default branch unless -b is given.
#   With nothing staged and no -m, only pushes.

main() {
  local msg="" have_msg=false all=false new_branch="" pr=false draft=false
  while [ $# -gt 0 ]; do
    case "$1" in
      -m) msg="${2-}"; have_msg=true; shift ;;
      -a) all=true ;;
      -b) new_branch="${2:?-b needs a branch name}"; shift ;;
      --pr) pr=true ;;
      --draft) draft=true ;;
      -h | --help) usage_from "$AICLI_LIB/cmd/ship.sh"; return 0 ;;
      *) die "ship: unknown argument: $1" ;;
    esac
    shift
  done
  need git
  in_repo
  [ "$msg" = "-" ] && msg=$(cat)

  local branch def
  branch=$(current_branch)
  def=$(default_branch)
  [ "$branch" = HEAD ] && die "ship: detached HEAD; check out a branch or pass -b"

  if [ -n "$new_branch" ]; then
    git show-ref -q --verify "refs/heads/$new_branch" && die "ship: branch already exists: $new_branch"
    git switch -q -c "$new_branch"
    branch="$new_branch"
  elif [ "$branch" = "$def" ]; then
    die "ship: on default branch '$def'; pass -b <branch>"
  fi

  $all && git add -A

  if ! git diff --cached --quiet 2> /dev/null || ! has_commits; then
    $have_msg && [ -n "$msg" ] || die "ship: staged changes need a message (-m)"
    printf '%s\n' "$msg" | git commit -q -F -
  elif $have_msg; then
    die "ship: nothing staged to commit (use -a, or drop -m to only push)"
  fi

  git remote get-url origin > /dev/null 2>&1 || die "ship: no 'origin' remote"
  local out
  if ! out=$(git push -q -u origin HEAD 2>&1); then
    printf '%s\n' "$out" >&2
    die "ship: push failed"
  fi

  echo "branch: $branch"
  echo "commit: $(git log -1 --format='%h %s')"

  if $pr; then
    if $draft; then
      "$AICLI_BIN" pr create --draft
    else
      "$AICLI_BIN" pr create
    fi
  fi
}
