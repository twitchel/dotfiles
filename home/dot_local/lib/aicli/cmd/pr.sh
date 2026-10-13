# summary: create or inspect the current branch's GitHub PR
# usage: aicli pr create [--title <t>] [--body-file <f>|-] [--draft]
#        aicli pr status
#
#   create   opens a PR against the default branch, or prints the existing one.
#            Title defaults to the first commit subject on the branch, body to
#            the list of commit subjects. The branch must already be pushed.
#   status   state, review decision and a checks summary for the branch's PR

pr_existing_url() {
  gh pr view --json url,state -q 'select(.state == "OPEN") | .url' 2> /dev/null || true
}

pr_create() {
  local title="" body_file="" draft=false
  while [ $# -gt 0 ]; do
    case "$1" in
      --title) title="${2:?--title needs a value}"; shift ;;
      --body-file) body_file="${2:?--body-file needs a path or -}"; shift ;;
      --draft) draft=true ;;
      *) die "pr create: unknown argument: $1" ;;
    esac
    shift
  done

  local branch def base url
  branch=$(current_branch)
  def=$(default_branch)
  [ "$branch" = HEAD ] && die "pr: detached HEAD"
  [ "$branch" = "$def" ] && die "pr: on default branch '$def'"
  git rev-parse -q --verify '@{u}' > /dev/null 2>&1 || die "pr: branch not pushed; run aicli ship"

  url=$(pr_existing_url)
  if [ -n "$url" ]; then
    echo "pr: $url (existing)"
    return 0
  fi

  base=$(base_ref)
  [ -n "$(git rev-list "$base..HEAD")" ] || die "pr: no commits ahead of $base"
  [ -n "$title" ] || title=$(git log --reverse --format=%s "$base..HEAD" | head -n 1)

  local args
  args=(--base "$def" --head "$branch" --title "$title")
  if [ -n "$body_file" ]; then
    args+=(--body-file "$body_file")
  else
    args+=(--body "$(git log --reverse --format='- %s' "$base..HEAD")")
  fi
  $draft && args+=(--draft)

  url=$(gh pr create "${args[@]}") || die "pr: gh pr create failed"
  echo "pr: $url"
}

pr_status() {
  local view checks
  view=$(gh pr view --json number,title,state,isDraft,reviewDecision,mergeable,url \
    -q '"#\(.number) \(.title)\n  state: \(.state)\(if .isDraft then " (draft)" else "" end), review: \(.reviewDecision // "none"), mergeable: \(.mergeable)\n  \(.url)"' 2> /dev/null) ||
    die "pr: no PR for branch $(current_branch)"
  echo "$view"

  # gh exits non-zero while checks are pending or failing; the JSON is still valid.
  checks=$(gh pr checks --json name,bucket 2> /dev/null || true)
  if [ -z "$checks" ] || [ "$checks" = "[]" ]; then
    echo "  checks: none"
    return 0
  fi
  printf '%s' "$checks" | jq -r '
    (group_by(.bucket) | map("\(.[0].bucket) \(length)") | join(", ")) as $sum
    | "  checks: \($sum)",
      (.[] | select(.bucket == "fail" or .bucket == "cancel") | "    \(.bucket): \(.name)")'
}

main() {
  local sub="${1:-}"
  [ $# -gt 0 ] && shift
  case "$sub" in
    create | status)
      need git gh jq
      in_repo
      "pr_$sub" "$@"
      ;;
    "" | -h | --help) usage_from "$AICLI_LIB/cmd/pr.sh" ;;
    *) die "pr: unknown subcommand: $sub" ;;
  esac
}
