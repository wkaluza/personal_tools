set -euo pipefail
if command -v shopt &>/dev/null; then
  shopt -s inherit_errexit
fi
THIS_SCRIPT_DIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"
cd "${THIS_SCRIPT_DIR}"

source "${THIS_SCRIPT_DIR}/shell_script_imports/preamble.bash"

function main
{
  log_info "Leaving docker swarm..."
  sudo docker swarm leave --force >/dev/null 2>&1 || true

  log_info "Deleting k8s cluster..."
  minikube delete >/dev/null 2>&1

  log_info "Pruning docker system..."
  docker system prune --force >/dev/null 2>&1

  log_info "Restarting docker..."
  sudo systemctl restart docker >/dev/null 2>&1

  log_info "Success: $(basename "$0")"
}

main
