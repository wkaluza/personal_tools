shopt -s histappend
shopt -s cmdhist
HISTFILESIZE=1000000
HISTSIZE=1000000
# HISTIGNORE='pwd:top:ps'
HISTCONTROL=ignorespace:erasedups
PROMPT_COMMAND='history -n ; history -a'
PATH="$PATH":"${HOME}/.local/bin"
SSH_AUTH_SOCK="$(gpgconf --list-dirs | grep ssh | sed -n 's/.*:\(\/.*$\)/\1/p')"
eval "$(gh completion --shell bash)"