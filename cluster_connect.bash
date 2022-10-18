set -euo pipefail
if command -v shopt &>/dev/null; then
  shopt -s inherit_errexit
fi
THIS_SCRIPT_DIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"
cd "${THIS_SCRIPT_DIR}"

source "${THIS_SCRIPT_DIR}/shell_script_imports/preamble.bash"

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

function container_has_label
{
  local label_name="$1"
  local label_value="$2"
  local container_id="$3"

  docker container list \
    --no-trunc \
    --filter label="${label_name}=${label_value}" \
    --format '{{ json . }}' |
    jq --raw-output '.ID' - |
    grep -E "^${container_id}$"
}

function connect_stacks_to_minikube
{
  log_info "Connecting stack containers to minikube network..."

  list_all_stacks |
    for_each list_stack_services |
    for_each list_service_tasks |
    for_each list_task_containers |
    for_each filter container_has_label \
      "wk.connect.cluster-cnr8lm0i" \
      "true" |
    for_each no_fail connect_container_to_network \
      "minikube" >/dev/null 2>&1
}

function main
{
  connect_stacks_to_minikube

  log_info "Success $(basename "$0")"
}

main
