set -euo pipefail
shopt -s inherit_errexit

THIS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
cd "${THIS_SCRIPT_DIR}"

function main
{
  local session_name="main_session"
  local window_name="main_window"

  tmux attach-session -t "${session_name}:${window_name}"
}

main
