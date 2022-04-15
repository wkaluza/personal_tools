set -euo pipefail
shopt -s inherit_errexit

THIS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

source "${THIS_SCRIPT_DIR}/shell_script_imports/common.bash"
source "${THIS_SCRIPT_DIR}/shell_script_imports/git_helpers.bash"

function main
{
  run_in_context \
    "${THIS_SCRIPT_DIR}" \
    git_get_latest

  bash "${THIS_SCRIPT_DIR}/startup_impl.bash"
}

main
