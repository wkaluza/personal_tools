shopt -s histappend
shopt -s cmdhist
HISTFILESIZE=1000000
HISTSIZE=1000000
HISTIGNORE="pwd:top:ps"
HISTCONTROL=ignorespace:erasedups
PROMPT_COMMAND="history -n ; history -a"
PATH="$PATH:${HOME}/.local/bin"

export HISTFILESIZE \
  HISTSIZE \
  HISTIGNORE \
  HISTCONTROL \
  PROMPT_COMMAND \
  PATH
