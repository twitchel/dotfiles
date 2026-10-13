# Shared helpers, sourced by the aicli dispatcher. Bash 3.2 compatible: macOS runs /bin/bash.

CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"

die() {
  printf 'aicli: %s\n' "$*" >&2
  exit 1
}

# usage_from <file> — print the leading "#" comment block after the summary line.
usage_from() {
  sed -n '/^# usage:/,/^[^#]/{/^#/s/^# \{0,1\}//p;}' "$1"
}

need() {
  local b
  for b in "$@"; do
    command -v "$b" > /dev/null 2>&1 || die "missing dependency: $b"
  done
}

in_repo() {
  git rev-parse --is-inside-work-tree > /dev/null 2>&1 || die "not inside a git repository"
}

has_commits() {
  git rev-parse -q --verify HEAD > /dev/null 2>&1
}

# Branch name, or "HEAD" when detached.
current_branch() {
  git symbolic-ref -q --short HEAD 2> /dev/null || echo HEAD
}

# origin/HEAD if known, else the first of main/master that exists locally.
default_branch() {
  local ref b
  if ref=$(git symbolic-ref -q --short refs/remotes/origin/HEAD 2> /dev/null); then
    echo "${ref#origin/}"
    return
  fi
  for b in main master; do
    if git show-ref -q --verify "refs/heads/$b"; then
      echo "$b"
      return
    fi
  done
  echo main
}

# The ref to diff a branch against: origin/<default> when fetched, else the local branch.
base_ref() {
  local def
  def=$(default_branch)
  if git show-ref -q --verify "refs/remotes/origin/$def"; then
    echo "origin/$def"
  else
    echo "$def"
  fi
}

# Plugin ids set to true in settings.json, one per line.
plugins_enabled() {
  local f="$CLAUDE_DIR/settings.json"
  [ -f "$f" ] || return 0
  jq -r '.enabledPlugins // {} | to_entries[] | select(.value == true) | .key' "$f"
}

plugins_installed() {
  local f="$CLAUDE_DIR/plugins/installed_plugins.json"
  [ -f "$f" ] || return 0
  jq -r '.plugins // {} | keys[]' "$f"
}

# Enabled plugin ids with no install record.
plugins_missing() {
  local installed
  installed=$(plugins_installed)
  plugins_enabled | while IFS= read -r id; do
    printf '%s\n' "$installed" | grep -qxF "$id" || echo "$id"
  done
}
