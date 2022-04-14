set -euo pipefail
shopt -s inherit_errexit

THIS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

source "${THIS_SCRIPT_DIR}/shell_script_imports/logging.bash"
source "${THIS_SCRIPT_DIR}/shell_script_imports/common.bash"

function get_swarm_state
{
  docker system info --format='{{ json . }}' |
    jq --raw-output '.Swarm.LocalNodeState' -
}

function docker_compose_push
{
  local registry_image_ref="$1"
  local reverse_proxy_image_ref="$2"
  local local_node_id="$3"
  local compose_file="$4"

  log_info "Pushing registry stack images..."

  DOCKER_REGISTRY_IMAGE_REFERENCE="${registry_image_ref}" \
    REVERSE_PROXY_IMAGE_REFERENCE="${reverse_proxy_image_ref}" \
    LOCAL_NODE_ID="${local_node_id}" \
    PROJECT_ROOT_DIR="${THIS_SCRIPT_DIR}" \
    docker compose \
    --file "${compose_file}" \
    push >/dev/null 2>&1
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

function get_local_node_id
{
  docker node ls --format='{{ json . }}' |
    jq --slurp '. | map(select( .Self == true ))' - |
    jq \
      --raw-output \
      'if . | length == 1 then .[0].ID else error("Expected exactly one local node") end' -
}

function is_registry_stack_running
{
  local stack_name="$1"

  docker stack ls --format '{{ json . }}' |
    jq \
      --slurp \
      "map(select( .Name == \"${stack_name}\" ))" - |
    jq \
      --raw-output \
      'if . | length == 1 then .[0].Name else error("Expected stack not found") end' - 2>/dev/null |
    head -n 1 |
    grep -E "^${stack_name}$" &>/dev/null
}

function start_registry_stack
{
  local registry_host="$1"
  local local_node_id="$2"
  local compose_file="$3"
  local stack_name="$4"
  local registry_image_ref="$5"
  local reverse_proxy_image_ref="$6"

  local defer_push="false"

  log_info "Building registry stack images..."

  DOCKER_REGISTRY_IMAGE_REFERENCE="${registry_image_ref}" \
    REVERSE_PROXY_IMAGE_REFERENCE="${reverse_proxy_image_ref}" \
    LOCAL_NODE_ID="${local_node_id}" \
    PROJECT_ROOT_DIR="${THIS_SCRIPT_DIR}" \
    docker compose \
    --file "${compose_file}" \
    build >/dev/null 2>&1

  if is_registry_stack_running "${stack_name}"; then
    docker_compose_push \
      "${registry_image_ref}" \
      "${reverse_proxy_image_ref}" \
      "${local_node_id}" \
      "${compose_file}"
  else
    defer_push="true"
  fi

  log_info "Deploying registry stack..."

  DOCKER_REGISTRY_IMAGE_REFERENCE="${registry_image_ref}" \
    REVERSE_PROXY_IMAGE_REFERENCE="${reverse_proxy_image_ref}" \
    LOCAL_NODE_ID="${local_node_id}" \
    PROJECT_ROOT_DIR="${THIS_SCRIPT_DIR}" \
    docker stack deploy \
    --compose-file "${compose_file}" \
    --prune \
    "${stack_name}" >/dev/null 2>&1

  retry_until_success \
    "ping_registry ${registry_host}" \
    ping_registry "${registry_host}"

  log_info "Registry stack deployed successfully"

  if [[ "${defer_push}" == "true" ]]; then
    docker_compose_push \
      "${registry_image_ref}" \
      "${reverse_proxy_image_ref}" \
      "${local_node_id}" \
      "${compose_file}"
  fi
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
  local local_registry_host="docker.registry.local"

  local compose_file="${THIS_SCRIPT_DIR}/local_docker_registry.json"
  local stack_name="local_registry_stack"
  local registry_image_ref="${local_registry_host}/registry"
  local reverse_proxy_image_ref="${local_registry_host}/nginx"

  local hosts_file="/etc/hosts"
  if ! cat "${hosts_file}" | grep "${local_registry_host}" >/dev/null; then
    log_info "Need to add ${local_registry_host} to ${hosts_file} ..."
    echo "127.0.0.1 ${local_registry_host}" | sudo tee --append "${hosts_file}"
  fi

  local local_node_id
  local_node_id="$(get_local_node_id)"

  start_registry_stack \
    "${local_registry_host}" \
    "${local_node_id}" \
    "${compose_file}" \
    "${stack_name}" \
    "${registry_image_ref}" \
    "${reverse_proxy_image_ref}"
}

function main
{
  ensure_docker_swarm_init
  ensure_local_docker_registry_is_running

  log_info "Success $(basename "$0")"
}

main
