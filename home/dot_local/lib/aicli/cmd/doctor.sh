# shellcheck shell=bash
# summary: health check: deps, gh auth, Claude gateway, settings drift, plugins
# usage: aicli doctor
#
#   Prints one ok/warn/fail line per check. Exits 1 if any check fails.

DOCTOR_FAILED=false

report() {
  local level="$1"
  shift
  printf '%-4s %s\n' "$level" "$*"
  [ "$level" = fail ] && DOCTOR_FAILED=true
  return 0
}

doctor_deps() {
  local b
  for b in git jq curl; do
    if command -v "$b" > /dev/null 2>&1; then report ok "$b"; else report fail "$b missing"; fi
  done
  for b in gh claude chezmoi; do
    if command -v "$b" > /dev/null 2>&1; then report ok "$b"; else report warn "$b missing"; fi
  done
}

doctor_gh() {
  command -v gh > /dev/null 2>&1 || return 0
  if gh auth status > /dev/null 2>&1; then
    report ok "gh authenticated"
  else
    report warn "gh not authenticated: run gh auth login"
  fi
}

doctor_gateway() {
  local url="${ANTHROPIC_BASE_URL:-}" code
  if [ -z "$url" ] && [ -f "$CLAUDE_DIR/settings.json" ]; then
    url=$(jq -r '.env.ANTHROPIC_BASE_URL // empty' "$CLAUDE_DIR/settings.json")
  fi
  if [ -z "$url" ]; then
    report ok "claude api: direct (no ANTHROPIC_BASE_URL)"
    return 0
  fi
  # Any HTTP status means reachable; 000 means no connection.
  code=$(curl -s -o /dev/null -m 5 -w '%{http_code}' "$url" || true)
  if [ "$code" = 000 ] || [ -z "$code" ]; then
    report fail "gateway unreachable: $url"
  else
    report ok "gateway reachable: $url (HTTP $code)"
  fi
}

doctor_settings() {
  command -v chezmoi > /dev/null 2>&1 || return 0
  local target="$CLAUDE_DIR/settings.json"
  chezmoi managed --include files 2> /dev/null | grep -qx '.claude/settings.json' || return 0
  if [ -z "$(chezmoi diff "$target" 2> /dev/null)" ]; then
    report ok "settings.json matches chezmoi"
  else
    report warn "settings.json drifted from managed keys: run chezmoi apply"
  fi
}

doctor_plugins() {
  [ -f "$CLAUDE_DIR/settings.json" ] || return 0
  local missing
  missing=$(plugins_missing)
  if [ -z "$missing" ]; then
    report ok "enabled plugins installed"
  else
    report warn "enabled but not installed: $(printf '%s' "$missing" | tr '\n' ' ') (run aicli plugins sync)"
  fi
}

main() {
  case "${1:-}" in
    -h | --help) usage_from "$AICLI_LIB/cmd/doctor.sh"; return 0 ;;
    "") ;;
    *) die "doctor: unknown argument: $1" ;;
  esac
  doctor_deps
  command -v jq > /dev/null 2>&1 || die "doctor: jq required for remaining checks"
  doctor_gh
  doctor_gateway
  doctor_settings
  doctor_plugins
  if command -v claude > /dev/null 2>&1; then
    report ok "claude $(claude --version 2> /dev/null | head -n 1)"
  fi
  ! $DOCTOR_FAILED
}
