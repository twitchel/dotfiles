## ---- Applications ---- ##
if command -v eza > /dev/null; then
  alias ls="eza --color=always --long --git --icons=always"
fi
if command -v z > /dev/null; then
  alias cd="z"
fi
alias mkcd="take"

alias v="nvim" # neovim
alias sv="sudoedit"
alias t="tmux"
alias g="git"
alias lg="lazygit"

alias rav="rsync -rav"
