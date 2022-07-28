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

function ping_hub_from_cluster
{
  local scheme="https"
  local endpoint="_/revision"

  minikube ssh -- \
    curl --silent \
    "${scheme}://${DOMAIN_MAIN_REVERSE_PROXY_cab92795}/${endpoint}" |
    grep "vcs_in_use"
}

function ensure_connection_to_swarm
{
  log_info "Testing connection to swarm..."

  retry_until_success \
    "ping_hub_from_cluster" \
    ping_hub_from_cluster

  log_info "Swarm connected"
}

function wait_for_k8s_node_ready
{
  log_info "Waiting for k8s node readiness..."

  kubectl wait \
    node \
    --all \
    --for="condition=Ready" \
    --timeout="60s" >/dev/null
}

function _minikube_status_raw
{
  minikube status --output "json" 2>/dev/null
}

function minikube_status
{
  local status=""

  if _minikube_status_raw >/dev/null; then
    status="$(_minikube_status_raw |
      jq --sort-keys 'if . | type == "array" then .[] else . end' - |
      jq --raw-output '. | select(.Name == "minikube") | .Host' -)"
  fi

  if [[ "${status}" == "Running" ]]; then
    echo "running"
  elif [[ "${status}" == "Stopped" ]]; then
    echo "stopped"
  else
    echo "deleted"
  fi
}

function start_minikube
{
  log_info "Starting minikube..."

  local status
  status="$(minikube_status)"

  local mirror_url="https://${DOMAIN_DOCKER_REGISTRY_MIRROR_f334ec4f}"

  local host_path="${HOME}/.wk_k8s_storage___/minikube"
  local node_path="/wk_data"

  mkdir --parents "${host_path}"

  if [[ "${status}" == "deleted" ]]; then
    minikube start \
      --cpus 8 \
      --disk-size "100G" \
      --driver "docker" \
      --embed-certs \
      --memory "8G" \
      --mount "true" \
      --mount-string "${host_path}:${node_path}" \
      --nodes 2 \
      --registry-mirror="${mirror_url}" >/dev/null 2>&1
  elif [[ "${status}" == "stopped" ]]; then
    minikube start >/dev/null 2>&1
  fi
}

function install_root_ca_minikube
{
  log_info "Installing CA..."

  cp \
    "$(mkcert -CAROOT)/rootCA.pem" \
    "${HOME}/.minikube/certs"
}

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

function enable_load_balancer_support
{
  minikube tunnel >/dev/null 2>&1 &
  disown
}

function taint_control_plane
{
  local role="node-role.kubernetes.io/control-plane"

  kubectl taint node \
    --overwrite \
    --selector "${role}" \
    "${role}:NoSchedule" >/dev/null
}

function disable_default_storage_class
{
  # standard is minikube's name for the built-in storage class
  kubectl annotate \
    --overwrite \
    storageclass \
    "standard" \
    "storageclass.kubernetes.io/is-default-class=false" >/dev/null
}

function main
{
  install_root_ca_minikube
  start_minikube
  wait_for_k8s_node_ready
  connect_stacks_to_minikube
  ensure_connection_to_swarm
  taint_control_plane
  disable_default_storage_class
  enable_load_balancer_support

  log_info "Success $(basename "$0")"
}

main
