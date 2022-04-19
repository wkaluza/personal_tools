set -euo pipefail
shopt -s inherit_errexit

function main
{
  local session_name="main_session"
  local window_name="main_window"

  tmux attach-session -t "${session_name}:${window_name}"
}

main
