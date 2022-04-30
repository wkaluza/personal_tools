set -euo pipefail
shopt -s inherit_errexit

THIS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
cd "${THIS_SCRIPT_DIR}"

function main
{
  bash "${THIS_SCRIPT_DIR}/luks/mount.bash" \
    "sda" \
    "system"
  bash "${THIS_SCRIPT_DIR}/upgrade_apt_full.bash"
  bash "${THIS_SCRIPT_DIR}/prepare_docker_swarm.bash"
}

main
