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
  quiet sudo docker swarm leave --force || true

  log_info "Deleting k8s cluster..."
  quiet minikube delete

  log_info "Pruning docker system..."
  quiet docker system prune --force

  log_info "Restarting docker..."
  quiet sudo systemctl restart docker

  log_info "Deleting local k8s storage..."
  quiet sudo rm -rf "${HOME}/.wk_k8s_storage___/minikube/"

  log_info "Success: $(basename "$0")"
}

main
