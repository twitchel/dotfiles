# summary: list, update or install the Claude Code plugins enabled in settings.json
# usage: aicli plugins [list|update|sync]
#
#   list     enabled plugins with installed version (default)
#   update   refresh every marketplace, then update each enabled plugin
#   sync     add missing marketplaces from extraKnownMarketplaces, install missing plugins

plugins_list() {
  local installed="$CLAUDE_DIR/plugins/installed_plugins.json"
  [ -f "$installed" ] || installed=/dev/null
  plugins_enabled | while IFS= read -r id; do
    jq -r --arg id "$id" '
      (.plugins[$id] // [])[0] as $p
      | if $p then "\($id) \($p.version) \(($p.lastUpdated // "")[0:10])"
        else "\($id) not-installed" end' "$installed" 2> /dev/null ||
      echo "$id not-installed"
  done | awk '{ printf "%-50s %s %s\n", $1, $2, $3 }'
}

plugins_update() {
  need claude
  claude plugin marketplace update
  plugins_enabled | while IFS= read -r id; do
    claude plugin update "$id" || echo "aicli: update failed: $id" >&2
  done
}

# Source argument for `claude plugin marketplace add`, from settings extraKnownMarketplaces.
marketplace_source() {
  jq -r --arg m "$1" '
    .extraKnownMarketplaces[$m].source // empty
    | .repo // .url // .path // empty' "$CLAUDE_DIR/settings.json"
}

plugins_sync() {
  need claude
  local known="$CLAUDE_DIR/plugins/known_marketplaces.json" id market src
  plugins_missing | while IFS= read -r id; do
    market="${id#*@}"
    if ! { [ -f "$known" ] && jq -e --arg m "$market" 'has($m)' "$known" > /dev/null; }; then
      src=$(marketplace_source "$market")
      [ -n "$src" ] || { echo "aicli: no source for marketplace $market, skipping $id" >&2; continue; }
      claude plugin marketplace add "$src"
    fi
    claude plugin install "$id"
  done
}

main() {
  local sub="${1:-list}"
  case "$sub" in
    list | update | sync)
      need jq
      "plugins_$sub"
      ;;
    -h | --help) usage_from "$AICLI_LIB/cmd/plugins.sh" ;;
    *) die "plugins: unknown subcommand: $sub" ;;
  esac
}
