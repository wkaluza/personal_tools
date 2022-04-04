set -euo pipefail

THIS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

function main
{
  bash "${THIS_SCRIPT_DIR}/luks/mount.bash" sda
  bash "${THIS_SCRIPT_DIR}/upgrade_apt_full.bash"

  if docker --version >/dev/null; then
    bash "${THIS_SCRIPT_DIR}/prepare_docker_swarm.bash"
  fi
}

main
