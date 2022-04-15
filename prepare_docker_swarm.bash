set -euo pipefail
shopt -s inherit_errexit

THIS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

source "${THIS_SCRIPT_DIR}/shell_script_imports/logging.bash"
source "${THIS_SCRIPT_DIR}/shell_script_imports/common.bash"

LOCAL_REGISTRY_HOST="docker.registry.local"

DOCKER_REGISTRY_ROOT_DIR="${THIS_SCRIPT_DIR}/docker_registry"
LOCAL_SWARM_NODE_ID="<___not_a_valid_id___>"
NGINX_CONFIG_PATH="${THIS_SCRIPT_DIR}/docker_registry/reverse_proxy/nginx.conf"
NGINX_CONFIG_SHA256="$(file_sha256_digest "${NGINX_CONFIG_PATH}")"
NGINX_IMAGE="${LOCAL_REGISTRY_HOST}/nginx"
REGISTRY_IMAGE="${LOCAL_REGISTRY_HOST}/registry"

function run_with_compose_env
{
  local command="$1"
  local args=("${@:2}")

  env \
    DOCKER_REGISTRY_IMAGE_REFERENCE="${REGISTRY_IMAGE}" \
    LOCAL_NODE_ID="${LOCAL_SWARM_NODE_ID}" \
    NGINX_CONFIG="${NGINX_CONFIG_PATH}" \
    NGINX_CONFIG_DIGEST="${NGINX_CONFIG_SHA256}" \
    PROJECT_ROOT_DIR="${DOCKER_REGISTRY_ROOT_DIR}" \
    REVERSE_PROXY_IMAGE_REFERENCE="${NGINX_IMAGE}" \
    "${command}" \
    "${args[@]}" >/dev/null 2>&1
}

function get_swarm_state
{
  docker system info --format='{{ json . }}' |
    jq --raw-output '.Swarm.LocalNodeState' -
}

function docker_compose_push
{
  local compose_file="$1"

  log_info "Pushing registry stack images..."

  run_with_compose_env \
    docker compose \
    --file "${compose_file}" \
    push
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

function is_stack_running
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
    grep -E "^${stack_name}$" >/dev/null
}

function is_registry_ready
{
  local stack_name="$1"
  local registry_host="$2"

  if is_stack_running "${stack_name}"; then
    retry_until_success \
      "ping_registry ${registry_host}" \
      ping_registry "${registry_host}"
  else
    false
  fi
}

function start_registry_stack
{
  local compose_file="$1"
  local stack_name="$2"

  local defer_push="false"

  log_info "Building registry stack images..."

  run_with_compose_env \
    docker compose \
    --file "${compose_file}" \
    build \
    --pull

  if is_registry_ready \
    "${stack_name}" \
    "${LOCAL_REGISTRY_HOST}"; then
    docker_compose_push \
      "${compose_file}"
  else
    defer_push="true"
  fi

  log_info "Deploying registry stack..."

  run_with_compose_env \
    docker stack deploy \
    --compose-file "${compose_file}" \
    --prune \
    "${stack_name}"

  retry_until_success \
    "ping_registry ${LOCAL_REGISTRY_HOST}" \
    ping_registry "${LOCAL_REGISTRY_HOST}"

  log_info "Registry stack deployed successfully"

  if [[ "${defer_push}" == "true" ]]; then
    docker_compose_push \
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

function ensure_host_is_in_etc_hosts_file
{
  local host="$1"
  local ip="$2"

  local hosts_file="/etc/hosts"

  if ! cat "${hosts_file}" | grep "${host}" >/dev/null; then
    log_info "Need to add ${host} to ${hosts_file} ..."
    echo "${ip} ${host}" | sudo tee --append "${hosts_file}"
  fi
}

function ensure_local_docker_registry_is_running
{
  local compose_file="${THIS_SCRIPT_DIR}/local_docker_registry.json"
  local stack_name="local_registry_stack"

  ensure_host_is_in_etc_hosts_file \
    "${LOCAL_REGISTRY_HOST}" \
    "127.0.0.1"

  LOCAL_SWARM_NODE_ID="$(get_local_node_id)"

  start_registry_stack \
    "${compose_file}" \
    "${stack_name}"
}

function main
{
  ensure_docker_swarm_init
  ensure_local_docker_registry_is_running

  log_info "Success $(basename "$0")"
}

main
