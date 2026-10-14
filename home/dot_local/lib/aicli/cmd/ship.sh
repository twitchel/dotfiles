# shellcheck shell=bash
# summary: commit (optional), push the branch, optionally open a PR
# usage: aicli ship [-m <msg>|-m -] [-a [<path>[:<start>[-<end>]]...]] [-b <branch>] [--pr] [--draft]
#
#   -m MSG      commit message; "-" reads it from stdin. Required when there is anything to commit
#   -a [PATH..] stage first: everything (tracked and untracked), or only the given paths.
#               Paths run until the next option, so put -a last or follow its paths with an option.
#               PATH:START-END (or PATH:LINE) stages only the changes in a tracked file that touch
#               those lines of the working copy, at the granularity of `git diff -U0` hunks
#   -b BRANCH   create and switch to BRANCH before committing
#   --pr        then run `aicli pr create`
#   --draft     with --pr, open as draft
#
#   Refuses to commit or push on the default branch unless -b is given.
#   With nothing staged and no -m, only pushes.

# Keeps the `git diff -U0` hunks whose new-side lines overlap one of the
# space-separated START-END ranges; exits 1 if none do.
# shellcheck disable=SC2016
HUNK_FILTER='
BEGIN {
  n = split(ranges, r, " ")
  for (i = 1; i <= n; i++) { split(r[i], p, "-"); lo[i] = p[1] + 0; hi[i] = p[2] + 0 }
}
/^@@ / {
  in_hunk = 1
  match($0, /\+[0-9]+(,[0-9]+)?/)
  k = split(substr($0, RSTART + 1, RLENGTH - 1), q, ",")
  c = q[1] + 0; d = (k > 1) ? q[2] + 0 : 1
  # A pure deletion sits between new lines c and c+1.
  a = c; b = (d == 0) ? c + 1 : c + d - 1
  keep = 0
  for (i = 1; i <= n; i++) if (lo[i] <= b && hi[i] >= a) keep = 1
  if (keep) kept++
}
!in_hunk { print; next }
keep { print }
END { exit kept ? 0 : 1 }
'

stage_ranges() {
  local file="$1" ranges="$2" patch
  git ls-files --error-unmatch -- "$file" > /dev/null 2>&1 ||
    die "ship: line ranges need a tracked file: $file"
  patch=$(git diff -U0 --no-color --no-ext-diff -- "$file" | awk -v ranges="$ranges" "$HUNK_FILTER") ||
    die "ship: no unstaged changes in $file touch lines $ranges"
  printf '%s\n' "$patch" | git apply --cached --unidiff-zero - ||
    die "ship: could not stage lines $ranges of $file"
}

# Stages whole paths with `git add -A`, and PATH:START[-END] specs hunk by hunk.
stage_paths() {
  local whole=() rfile=() rrange=() arg i j f ranges seen
  local re='^(.+):([0-9]+)(-([0-9]+))?$'
  for arg in "$@"; do
    if [ ! -e "$arg" ] && [[ $arg =~ $re ]]; then
      rfile+=("${BASH_REMATCH[1]}")
      rrange+=("${BASH_REMATCH[2]}-${BASH_REMATCH[4]:-${BASH_REMATCH[2]}}")
    else
      whole+=("$arg")
    fi
  done
  if [ ${#whole[@]} -gt 0 ]; then
    git add -A -- "${whole[@]}" || die "ship: could not stage the given paths"
  fi
  i=0
  while [ "$i" -lt ${#rfile[@]} ]; do
    f="${rfile[$i]}"
    seen=false
    j=0
    while [ "$j" -lt "$i" ]; do
      [ "${rfile[$j]}" = "$f" ] && seen=true
      j=$((j + 1))
    done
    if ! $seen; then
      ranges=""
      j=$i
      while [ "$j" -lt ${#rfile[@]} ]; do
        [ "${rfile[$j]}" = "$f" ] && ranges="${ranges:+$ranges }${rrange[$j]}"
        j=$((j + 1))
      done
      stage_ranges "$f" "$ranges"
    fi
    i=$((i + 1))
  done
}

main() {
  local msg="" have_msg=false all=false new_branch="" pr=false draft=false
  local paths=()
  while [ $# -gt 0 ]; do
    case "$1" in
      -m) msg="${2-}"; have_msg=true; shift ;;
      -a)
        all=true
        while [ $# -gt 1 ] && [ "${2#-}" = "$2" ]; do
          paths+=("$2")
          shift
        done
        ;;
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

  if $all; then
    if [ ${#paths[@]} -gt 0 ]; then
      stage_paths "${paths[@]}"
    else
      git add -A
    fi
  fi

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
