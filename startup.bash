set -euo pipefail
if command -v shopt &>/dev/null; then
  shopt -s inherit_errexit
fi
THIS_SCRIPT_DIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"
cd "${THIS_SCRIPT_DIR}"

source "${THIS_SCRIPT_DIR}/shell_script_imports/preamble.bash"

function main
{
  if web_connection_working; then
    refresh_ssh_known_host \
      "github.com"
    quiet run_in_context \
      "${THIS_SCRIPT_DIR}" \
      git_get_latest \
      "origin" \
      "main"
  fi

  bash "${THIS_SCRIPT_DIR}/startup_impl.bash"

  log_info "Success $(basename "$0")"
}

main
