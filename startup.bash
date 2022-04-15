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

  bash "${THIS_SCRIPT_DIR}/luks/mount.bash" \
    "sda" \
    "system"
  bash "${THIS_SCRIPT_DIR}/prepare_docker_swarm.bash"
  bash "${THIS_SCRIPT_DIR}/upgrade_apt_full.bash"
}

main
