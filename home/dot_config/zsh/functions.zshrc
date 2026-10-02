## ---- worktrees: functions to make interacting with worktrees easier ---- ##
source "$ZDOTDIR/worktrees.functions.zshrc"

## ---- serve: serve the current directory over HTTP ---- ##
# serve [-d] [-a] <port> — mounts $PWD as the webroot of an nginx:alpine container.
# -d detaches; the container is named serve-<port> so it can be stopped again.
# -a publishes on all interfaces; the default is localhost only.
serve() {
  local daemon=0 all=0 opt
  local OPTIND=1
  while getopts ":da" opt; do
    case "$opt" in
      d) daemon=1 ;;
      a) all=1 ;;
      *) print -u2 "usage: serve [-d] [-a] <port>"; return 2 ;;
    esac
  done
  shift $((OPTIND - 1))

  local port="$1"
  if [[ -z "$port" || "$port" != <1-65535> ]]; then
    print -u2 "usage: serve [-d] [-a] <port>"
    return 2
  fi

  if ! command -v docker > /dev/null; then
    print -u2 "serve: docker is not installed"
    return 1
  fi

  local publish="127.0.0.1:$port:80"
  (( all )) && publish="$port:80"

  local -a args=(
    --rm
    --name "serve-$port"
    --publish "$publish"
    --volume "$PWD:/usr/share/nginx/html:ro"
    # The webroot is usually user_home_t, which container_t cannot read. Dropping
    # the label is preferable to :z, which would relabel the served directory.
    --security-opt label=disable
  )
  # Serves a directory index; without it nginx 403s on a directory with no index.html.
  [[ -f "$HOME/.config/nginx/serve.conf" ]] &&
    args+=(--volume "$HOME/.config/nginx/serve.conf:/etc/nginx/conf.d/default.conf:ro")

  local where="http://localhost:$port"
  (( all )) && where="$where (all interfaces)"

  if (( daemon )); then
    docker run --detach "${args[@]}" nginx:alpine > /dev/null || return
    print "serve: $PWD on $where (docker stop serve-$port)"
  else
    print "serve: $PWD on $where (ctrl-c to stop)"
    docker run "${args[@]}" nginx:alpine
  fi
}
