set -euo pipefail
shopt -s inherit_errexit

THIS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

source "${THIS_SCRIPT_DIR}/shell_script_imports/logging.bash"
source "${THIS_SCRIPT_DIR}/shell_script_imports/common.bash"

function get_swarm_state
{
  docker system info --format='{{json .}}' |
    jq -r '.Swarm.LocalNodeState' -
}

# Note: recursive function
function ensure_docker_swarm_init
{
  local swarm_state
  swarm_state="$(get_swarm_state)"

  local swarm_key_pass_id="wk_local_swarm_key"
  local swarm_key_magic_prefix="SWMKEY"

  if [[ "${swarm_state}" == "locked" ]]; then
    log_info "Swarm is locked, unlocking..."
    if pass show "${swarm_key_pass_id}" >/dev/null &&
      pass show "${swarm_key_pass_id}" |
      docker swarm unlock >/dev/null 2>&1; then
      log_info "Swarm unlocked successfully"
    else
      log_info "Cannot unlock swarm, need to leave and re-init..."

      docker swarm leave --force

      ensure_docker_swarm_init
    fi
  elif [[ "${swarm_state}" == "inactive" ]]; then
    log_info "Swarm is inactive, initialising..."

    docker swarm init --autolock |
      grep "${swarm_key_magic_prefix}" |
      sed -E "s/^.*(${swarm_key_magic_prefix}.*)$/\1/" |
      pass insert --multiline "${swarm_key_pass_id}" >/dev/null

    log_info "Swarm is now active"
  elif [[ "${swarm_state}" == "active" ]]; then
    log_info "Swarm is active"
  else
    log_error "Unexpected docker swarm state '${swarm_state}'"
    exit 1
  fi
}

function is_bootstrap_registry_running
{
  local registry_service_name="$1"

  docker service ls --format='{{ json . }}' |
    jq -s "map(select( .Name == \"${registry_service_name}\" ))" - |
    jq -r 'if . | length == 1 then .[0].Name else error("Expected service not found") end' - 2>/dev/null |
    head -n 1 |
    grep -E "^${registry_service_name}$" >/dev/null
}

function get_local_node_id
{
  docker node ls --format='{{ json . }}' |
    jq -s '.' - |
    jq '. | map(select( .Self == true ))' - |
    jq -r 'if . | length == 1 then .[0].ID else error("Expected exactly one local node") end' -
}

function start_bootstrap_registry
{
  local registry_service_name="$1"
  local bootstrap_registry_volume_name="$2"
  local registry_port="$3"
  local local_node_id="$4"

  local registry_image_version="2.8.1"

  local port_info="published=${registry_port},target=5000,mode=ingress,protocol=tcp"
  local volume_info="type=volume,source=${bootstrap_registry_volume_name},destination=/var/lib/registry"

  log_info "Starting service ${registry_service_name}..."

  if docker service create \
    --constraint "node.id==${local_node_id}" \
    --mode "global" \
    --mount "${volume_info}" \
    --name "${registry_service_name}" \
    --publish "${port_info}" \
    --quiet \
    "registry:${registry_image_version}" >/dev/null; then
    log_info "Service ${registry_service_name} started successfully"
  else
    log_error "Failed to start service ${registry_service_name}"
    exit 1
  fi
}

function is_registry_stack_running
{
  local stack_name="$1"

  docker stack ls --format '{{ json . }}' |
    jq -s "map(select( .Name == \"${stack_name}\" ))" - |
    jq -r 'if . | length == 1 then .[0].Name else error("Expected stack not found") end' - 2>/dev/null |
    head -n 1 |
    grep -E "^${stack_name}$" &>/dev/null
}

function start_registry_stack
{
  local registry_host="$1"
  local local_node_id="$2"
  local compose_file="$3"
  local stack_name="$4"

  log_info "Building registry stack images..."

  DOCKER_REGISTRY_HOST="${registry_host}" \
    LOCAL_NODE_ID="${local_node_id}" \
    PROJECT_ROOT_DIR="${THIS_SCRIPT_DIR}" \
    docker compose \
    --file "${compose_file}" \
    build >/dev/null

  log_info "Pushing registry stack images..."

  DOCKER_REGISTRY_HOST="${registry_host}" \
    LOCAL_NODE_ID="${local_node_id}" \
    PROJECT_ROOT_DIR="${THIS_SCRIPT_DIR}" \
    docker compose \
    --file "${compose_file}" \
    push >/dev/null 2>&1

  log_info "Deploying registry stack..."

  DOCKER_REGISTRY_HOST="${registry_host}" \
    LOCAL_NODE_ID="${local_node_id}" \
    PROJECT_ROOT_DIR="${THIS_SCRIPT_DIR}" \
    docker stack deploy \
    --compose-file "${compose_file}" \
    "${stack_name}" >/dev/null

  log_info "Registry stack deployed successfully"
}

function ping_registry
{
  local registry_host="$1"

  local scheme="http"
  local endpoint="v2/_catalog"

  curl --silent \
    "${scheme}://${registry_host}/${endpoint}" |
    grep "repositories"
}

function rm_volume
{
  local volume_name="$1"

  docker volume rm \
    --force \
    "${volume_name}"
}

function ensure_local_docker_registry_is_running
{
  local local_registry_host="$1"

  local registry_port=5555
  local bootstrap_registry_host="localhost:${registry_port}"
  local bootstrap_registry_service_name="bootstrap_local_registry"
  local bootstrap_registry_volume_name="bootstrap_local_registry_volume"
  local compose_file="${THIS_SCRIPT_DIR}/local_docker_registry.json"
  local stack_name="local_registry_stack"

  local hosts_file="/etc/hosts"
  if ! cat "${hosts_file}" | grep "${local_registry_host}" >/dev/null; then
    log_info "Need to add ${local_registry_host} to ${hosts_file} ..."
    echo "127.0.0.1 ${local_registry_host}" | sudo tee --append "${hosts_file}"
  fi

  local local_node_id
  local_node_id="$(get_local_node_id)"

  if is_registry_stack_running "${stack_name}"; then
    log_info "Registry stack is already up"
  else
    if is_bootstrap_registry_running "${bootstrap_registry_service_name}"; then
      log_info "Bootstrap registry service is already up"
    else
      start_bootstrap_registry \
        "${bootstrap_registry_service_name}" \
        "${bootstrap_registry_volume_name}" \
        "${registry_port}" \
        "${local_node_id}"
    fi

    retry_until_success \
      "ping_registry ${bootstrap_registry_host}" \
      ping_registry "${bootstrap_registry_host}"

    start_registry_stack \
      "${bootstrap_registry_host}" \
      "${local_node_id}" \
      "${compose_file}" \
      "${stack_name}"

    docker service rm \
      "${bootstrap_registry_service_name}" >/dev/null

    retry_until_success \
      "rm_volume ${bootstrap_registry_volume_name}" \
      rm_volume "${bootstrap_registry_volume_name}"
  fi

  retry_until_success \
    "ping_registry ${local_registry_host}" \
    ping_registry "${local_registry_host}"
}

function main
{
  local local_registry_host="docker.registry.local"

  ensure_docker_swarm_init
  ensure_local_docker_registry_is_running \
    "${local_registry_host}"

  log_info "Success $(basename "$0")"
}

main
