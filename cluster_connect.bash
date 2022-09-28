set -euo pipefail
if command -v shopt &>/dev/null; then
  shopt -s inherit_errexit
fi
THIS_SCRIPT_DIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"
cd "${THIS_SCRIPT_DIR}"

source "${THIS_SCRIPT_DIR}/shell_script_imports/logging.bash"
source "${THIS_SCRIPT_DIR}/shell_script_imports/common.bash"
source "${THIS_SCRIPT_DIR}/shell_script_imports/git_helpers.bash"
source "${THIS_SCRIPT_DIR}/shell_script_imports/gogs_helpers.bash"

source <(cat "${THIS_SCRIPT_DIR}/local_domains.json" |
  jq '. | to_entries' - |
  jq '. | map( "\(.key)=\"\(.value)\"" )' - |
  jq --raw-output '. | .[]' - |
  sort)

function list_all_stacks
{
  docker stack ls --format '{{ .Name }}'
}

function list_stack_services
{
  local stack="$1"

  docker stack services \
    --format '{{ .ID }}' \
    "${stack}"
}

function list_service_tasks
{
  local service="$1"

  docker service ps \
    --no-trunc \
    --format '{{ .ID }}' \
    "${service}"
}

function list_task_containers
{
  local task="$1"

  docker inspect \
    --format '{{ .Status.ContainerStatus.ContainerID }}' \
    "${task}"
}

function connect_container_to_network
{
  local network="$1"
  local container="$2"

  docker network connect \
    "${network}" \
    "${container}"
}

function connect_stacks_to_minikube
{
  log_info "Connecting stack containers to minikube network..."

  list_all_stacks |
    for_each list_stack_services |
    for_each list_service_tasks |
    for_each list_task_containers |
    for_each no_fail connect_container_to_network \
      "minikube" >/dev/null 2>&1
}

function main
{
  connect_stacks_to_minikube

  log_info "Success $(basename "$0")"
}

main
