set -euo pipefail
if command -v shopt &>/dev/null; then
  shopt -s inherit_errexit
fi
THIS_SCRIPT_DIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"

source "${THIS_SCRIPT_DIR}/shell_script_imports/preamble.bash"

function main
{
  log_info "Connecting stack containers to minikube network..."

  list_all_stacks |
    for_each connect_stack_containers_to_network \
      "minikube" \
      "auto" \
      "wk.connect.cluster-cnr8lm0i" \
      "true"

  log_info "Success $(basename "$0")"
}

main
