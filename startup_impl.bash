set -euo pipefail
if command -v shopt &>/dev/null; then
  shopt -s inherit_errexit
fi
THIS_SCRIPT_DIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"
cd "${THIS_SCRIPT_DIR}"

function main
{
  bash "${THIS_SCRIPT_DIR}/luks/mount.bash" \
    "sda" \
    "system"
  bash "${THIS_SCRIPT_DIR}/upgrade_apt_full.bash"
  bash "${THIS_SCRIPT_DIR}/prepare_docker_swarm.bash"
  bash "${THIS_SCRIPT_DIR}/cluster_connect.bash"
  bash "${THIS_SCRIPT_DIR}/bootstrap_infrastructure.bash"
}

main
