#!/usr/bin/env bash
# Claude Code status line.
# Segments (left to right): model | directory | git branch (+dirty marker) | context usage.
# Colours are the Catppuccin Mocha palette from ~/.config/starship/starship.toml, so the
# status line reads as a companion to (not a duplicate of) the starship prompt above it.

input=$(cat)

# Catppuccin Mocha, as 24-bit "R;G;B" for use with \033[38;2;<...>m
mauve='203;166;247'
peach='250;179;135'
yellow='249;226;175'
red='243;139;168'
green='166;227;161'
reset=$'\033[0m'

fg() { printf '\033[38;2;%sm' "$1"; }
sep='  ' # two spaces, matching the density of the starship prompt above

model=$(printf '%s' "$input" | jq -r '.model.display_name // "Claude"')
cwd=$(printf '%s' "$input" | jq -r '.workspace.current_dir // .cwd // empty')
dir=$(basename -- "${cwd:-/}")

segments=()

# 1. model, robot glyph
segments+=("$(fg "$mauve")$(printf '\xf0\x9f\xa4\x96') ${model}${reset}")

# 2. directory (basename only), folder glyph
segments+=("$(fg "$peach")$(printf '\xef\x81\xbb') ${dir}${reset}")

# 3. git branch + dirty marker; silently omitted outside a git repo
if [ -n "$cwd" ] && git -C "$cwd" --no-optional-locks rev-parse --is-inside-work-tree > /dev/null 2>&1; then
  branch=$(git -C "$cwd" --no-optional-locks branch --show-current 2>/dev/null)
  [ -z "$branch" ] && branch=$(git -C "$cwd" --no-optional-locks rev-parse --short HEAD 2>/dev/null)
  if [ -n "$branch" ]; then
    dirty=""
    if [ -n "$(git -C "$cwd" --no-optional-locks status --porcelain 2>/dev/null)" ]; then
      dirty="$(fg "$red")*${reset}"
    fi
    segments+=("$(fg "$yellow")$(printf '\xee\x9c\xa5') ${branch}${reset}${dirty}")
  fi
fi

# 4. context window usage, gauge glyph, colour scales green -> yellow -> red
pct=$(printf '%s' "$input" | jq -r '.context_window.used_percentage // empty')
if [ -n "$pct" ]; then
  pct_r=$(printf '%.0f' "$pct")
  colour="$green"
  [ "$pct_r" -ge 50 ] && colour="$yellow"
  [ "$pct_r" -ge 80 ] && colour="$red"
  segments+=("$(fg "$colour")$(printf '\xef\x83\xa4') ${pct_r}%${reset}")
fi

out=""
for s in "${segments[@]}"; do
  if [ -z "$out" ]; then
    out="$s"
  else
    out="${out}${sep}${s}"
  fi
done

printf '%b\n' "$out"
