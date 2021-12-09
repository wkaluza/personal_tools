shopt -s histappend
shopt -s cmdhist
HISTFILESIZE=1000000
HISTSIZE=1000000
HISTIGNORE="pwd:top:ps"
HISTCONTROL=ignorespace:erasedups
PROMPT_COMMAND="history -n ; history -a"
GOROOT="/usr/local/go"
GOPATH="${HOME}/go"
GOPRIVATE="github.com/wkaluza/*"
CGO_ENABLED=0
PATH="$PATH:${GOROOT}/bin"
PATH="$PATH:${GOPATH}/bin"
PATH="$PATH:${HOME}/.local/bin"
SSH_AUTH_SOCK="$(gpgconf --list-dirs | grep ssh | sed -n 's/.*:\(\/.*$\)/\1/p')"
eval "$(gh completion --shell bash)"
eval "$(rustup completions bash)"

export HISTFILESIZE \
  HISTSIZE \
  HISTIGNORE \
  HISTCONTROL \
  PROMPT_COMMAND \
  GOROOT \
  GOPATH \
  GOPRIVATE \
  CGO_ENABLED \
  PATH \
  SSH_AUTH_SOCK
