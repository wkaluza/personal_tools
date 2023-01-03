set -euo pipefail
if command -v shopt &>/dev/null; then
  shopt -s inherit_errexit
fi
THIS_SCRIPT_DIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"
cd "${THIS_SCRIPT_DIR}"

source "${THIS_SCRIPT_DIR}/shell_script_imports/preamble.bash"

function main
{
  refresh_ssh_known_host \
    "${DOMAIN_GIT_FRONTEND_df29c969}"
  refresh_ssh_known_host \
    "github.com"

  log_info "Success: $(basename "$0")"
}

main
