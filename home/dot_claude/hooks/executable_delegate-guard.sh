#!/bin/bash
# Delegation rules in one script: `pre-tool` denies main-session Edit/Write, `agent` caps subagent
# spawns per user prompt, `prompt` injects the reminder and resets that budget.

cfg="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
cfg="${cfg%/}"

# Bypass is user-controlled only: env var or toggle file.
bypass() {
  [ "${CLAUDE_INLINE_EDITS:-}" = 1 ] || [ -e "$cfg/inline-edits" ]
}

# under <path> <dir>: path is dir itself or inside it (directory boundary, not substring).
under() {
  local dir="${2%/}"
  [ -n "$dir" ] && case "$1" in "$dir" | "$dir"/*) return 0 ;; esac
  return 1
}

pre_tool() {
  if ! command -v jq > /dev/null 2>&1; then
    echo "delegate-guard: jq not found, allowing" >&2
    return 0
  fi
  local input agent path dir
  input=$(cat)
  agent=$(printf '%s' "$input" | jq -r '.agent_id // empty' 2> /dev/null)
  [ -n "$agent" ] && return 0
  bypass && return 0
  path=$(printf '%s' "$input" | jq -r '.tool_input.file_path // .tool_input.notebook_path // empty' 2> /dev/null)
  for dir in "$cfg" /tmp /private/tmp "${TMPDIR:-}"; do
    [ -n "$path" ] && under "$path" "$dir" && return 0
  done
  deny "The main session does not edit project files. Delegate this edit: writer-quick (mechanical, 1-2 files, full spec), writer (scoped change with tests), writer-deep (cross-file or design judgment). Brief it with the exact files, the change and the checks to run, then commit its work with aicli ship. Do not work around this with Bash file writes."
}

# session_file <json>: per-session budget file path, empty when jq or a usable session_id is missing.
session_file() {
  local sid
  command -v jq > /dev/null 2>&1 || return 0
  sid=$(printf '%s' "$1" | jq -r '.session_id // empty' 2> /dev/null)
  sid=${sid//[^A-Za-z0-9_-]/}
  [ -n "$sid" ] && printf '%s/claude-agent-budget/%s' "${TMPDIR:-/tmp}" "$sid"
  return 0
}

# cap <value> <default>: numeric value, else the default.
cap() {
  case "$1" in '' | *[!0-9]*) echo "$2" ;; *) echo "$1" ;; esac
}

deny() {
  jq -n --arg reason "$1" \
    '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $reason}}'
}

# Each call appends a unique line, then its line number is its place in the queue, so
# concurrent calls get a deterministic verdict without locks. 0 = unlimited.
agent() {
  if ! command -v jq > /dev/null 2>&1; then
    echo "delegate-guard: jq not found, allowing" >&2
    return 0
  fi
  local input file type token n deep total_cap deep_cap
  input=$(cat)
  file=$(session_file "$input")
  [ -n "$file" ] || return 0
  type=$(printf '%s' "$input" | jq -r '.tool_input.subagent_type // empty' 2> /dev/null)
  type=${type//[^A-Za-z0-9_:.-]/}
  total_cap=$(cap "${CLAUDE_AGENT_CAP:-}" 8)
  deep_cap=$(cap "${CLAUDE_DEEP_CAP:-}" 2)
  mkdir -p "${file%/*}" 2> /dev/null || return 0
  token="$$-$RANDOM"
  printf '%s %s\n' "$token" "$type" >> "$file" 2> /dev/null || return 0
  n=$(grep -n -m1 "^$token " "$file" | cut -d: -f1)
  [ -n "$n" ] || return 0
  if [ "$total_cap" -gt 0 ] && [ "$n" -gt "$total_cap" ]; then
    deny "Agent budget for this prompt is used up ($total_cap spawns). Batch the remaining work: give one agent the whole file list or task set instead of one agent per item. If more agents are genuinely needed, ask the user."
    return 0
  fi
  case "$type" in
    reader-deep | writer-deep)
      deep=$(head -n "$n" "$file" | grep -c -E ' (reader|writer)-deep$')
      if [ "$deep_cap" -gt 0 ] && [ "$deep" -gt "$deep_cap" ]; then
        deny "Deep-agent budget for this prompt is used up ($deep_cap reader-deep/writer-deep). Use reader or writer, or fold the work into one deep agent."
      fi
      ;;
  esac
  return 0
}

prompt() {
  local file
  file=$(session_file "$(cat 2> /dev/null)")
  [ -n "$file" ] && rm -f "$file" 2> /dev/null
  bypass && return 0
  echo "Delegation: file edits go to writer-quick / writer / writer-deep (main-session Edit/Write on project files is blocked); multi-file searches, flow tracing and reviews go to reader-quick / reader / reader-deep. Single-fact lookups in a known file may stay inline."
}

case "${1:-}" in
  pre-tool) pre_tool ;;
  agent) agent ;;
  prompt) prompt ;;
  *) echo "usage: delegate-guard.sh pre-tool|agent|prompt" >&2 ;;
esac
exit 0
