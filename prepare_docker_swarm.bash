set -euo pipefail
shopt -s inherit_errexit

THIS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

source "${THIS_SCRIPT_DIR}/shell_script_imports/logging.bash"
source "${THIS_SCRIPT_DIR}/shell_script_imports/common.bash"
source "${THIS_SCRIPT_DIR}/shell_script_imports/git_helpers.bash"

LOCAL_REGISTRY_HOST="docker.registry.local"
MIRROR_REGISTRY_HOST="docker.registry.mirror"

function generate_git_commit
{
  echo \
    "commit:" \
    "\"$(git rev-parse 'HEAD' 2>/dev/null)\""
}

function generate_git_branch
{
  echo \
    "branch:" \
    "\"$(git branch --show-current)\""
}

function generate_git_wip
{
  echo \
    "work_in_progress:" \
    "$(if is_git_repo && ! repo_is_clean; then echo "true"; else echo "false"; fi)"
}

function generate_revision_data
{
  local output='{"vcs_in_use":""}'

  if is_git_repo; then
    output=$(echo '{ "vcs_in_use": "git" }' |
      jq ". + { git: { $(generate_git_commit), $(generate_git_wip), $(generate_git_branch) }}" -)
  fi

  echo "${output}" |
    jq --sort-keys --compact-output '.' - |
    tr -d '\n'
}

REVISION_DATA_JSON="$(cd "${THIS_SCRIPT_DIR}" && generate_revision_data)"

NETWORK_NAME_INTERNAL="local_registry_internal"

DOCKER_REGISTRY_ROOT_DIR="${THIS_SCRIPT_DIR}/docker_registry"
LOCAL_SWARM_NODE_ID="<___not_a_valid_id___>"

NGINX_CONFIG_PATH="${DOCKER_REGISTRY_ROOT_DIR}/reverse_proxy/nginx.conf.template"
NGINX_CONFIG_SHA256="$(cat "${NGINX_CONFIG_PATH}" |
  sha256 |
  take_first 8)"
NGINX_IMAGE="${LOCAL_REGISTRY_HOST}/nginx"

REGISTRY_CONFIG_PATH="${DOCKER_REGISTRY_ROOT_DIR}/registry/config.yml"
REGISTRY_CONFIG_SHA256="$(cat "${REGISTRY_CONFIG_PATH}" |
  sha256 |
  take_first 8)"
REGISTRY_IMAGE="${LOCAL_REGISTRY_HOST}/registry"

MIRROR_CONFIG_PATH="${DOCKER_REGISTRY_ROOT_DIR}/registry/config_mirror.yml"
MIRROR_CONFIG_SHA256="$(cat "${MIRROR_CONFIG_PATH}" |
  sha256 |
  take_first 8)"

CERTS_DIR="${HOME}/.certificates___"

DOCKER_REGISTRY_LOCAL_CERT_PATH="${CERTS_DIR}/${LOCAL_REGISTRY_HOST}.pem"
DOCKER_REGISTRY_LOCAL_CERT_SECURE_DIGEST="$(cat "${DOCKER_REGISTRY_LOCAL_CERT_PATH}" |
  encrypt_deterministically "${DOCKER_REGISTRY_LOCAL_CERT_PATH}" |
  sha256 |
  take_first 8)"
DOCKER_REGISTRY_LOCAL_KEY_PATH="${CERTS_DIR}/${LOCAL_REGISTRY_HOST}-key.pem"
DOCKER_REGISTRY_LOCAL_KEY_SECURE_DIGEST="$(cat "${DOCKER_REGISTRY_LOCAL_KEY_PATH}" |
  encrypt_deterministically "${DOCKER_REGISTRY_LOCAL_KEY_PATH}" |
  sha256 |
  take_first 8)"

DOCKER_REGISTRY_MIRROR_CERT_PATH="${CERTS_DIR}/${MIRROR_REGISTRY_HOST}.pem"
DOCKER_REGISTRY_MIRROR_CERT_SECURE_DIGEST="$(cat "${DOCKER_REGISTRY_MIRROR_CERT_PATH}" |
  encrypt_deterministically "${DOCKER_REGISTRY_MIRROR_CERT_PATH}" |
  sha256 |
  take_first 8)"
DOCKER_REGISTRY_MIRROR_KEY_PATH="${CERTS_DIR}/${MIRROR_REGISTRY_HOST}-key.pem"
DOCKER_REGISTRY_MIRROR_KEY_SECURE_DIGEST="$(cat "${DOCKER_REGISTRY_MIRROR_KEY_PATH}" |
  encrypt_deterministically "${DOCKER_REGISTRY_MIRROR_KEY_PATH}" |
  sha256 |
  take_first 8)"

MIRROR_REGISTRY_CONFIG_SELECT=""

function run_with_compose_env
{
  local command="$1"
  local args=("${@:2}")

  local environment
  environment="$(
    cat <<EOF | tr '\n' ' '
DOCKER_REGISTRY_IMAGE_REFERENCE="${REGISTRY_IMAGE}"
DOCKER_REGISTRY_LOCAL_CERT="${DOCKER_REGISTRY_LOCAL_CERT_PATH}"
DOCKER_REGISTRY_LOCAL_CERT_DIGEST="${DOCKER_REGISTRY_LOCAL_CERT_SECURE_DIGEST}"
DOCKER_REGISTRY_LOCAL_KEY="${DOCKER_REGISTRY_LOCAL_KEY_PATH}"
DOCKER_REGISTRY_LOCAL_KEY_DIGEST="${DOCKER_REGISTRY_LOCAL_KEY_SECURE_DIGEST}"
DOCKER_REGISTRY_MIRROR_CERT="${DOCKER_REGISTRY_MIRROR_CERT_PATH}"
DOCKER_REGISTRY_MIRROR_CERT_DIGEST="${DOCKER_REGISTRY_MIRROR_CERT_SECURE_DIGEST}"
DOCKER_REGISTRY_MIRROR_KEY="${DOCKER_REGISTRY_MIRROR_KEY_PATH}"
DOCKER_REGISTRY_MIRROR_KEY_DIGEST="${DOCKER_REGISTRY_MIRROR_KEY_SECURE_DIGEST}"
LOCAL_NODE_ID="${LOCAL_SWARM_NODE_ID}"
LOCAL_REGISTRY_HOST="${LOCAL_REGISTRY_HOST}"
MIRROR_REGISTRY_CONFIG="${MIRROR_CONFIG_PATH}"
MIRROR_REGISTRY_CONFIG_DIGEST="${MIRROR_CONFIG_SHA256}"
MIRROR_REGISTRY_CONFIG_SELECT="${MIRROR_REGISTRY_CONFIG_SELECT}"
MIRROR_REGISTRY_HOST="${MIRROR_REGISTRY_HOST}"
NETWORK_NAME_INTERNAL="${NETWORK_NAME_INTERNAL}"
NGINX_CONFIG="${NGINX_CONFIG_PATH}"
NGINX_CONFIG_DIGEST="${NGINX_CONFIG_SHA256}"
PROJECT_ROOT_DIR="${DOCKER_REGISTRY_ROOT_DIR}"
REGISTRY_CONFIG="${REGISTRY_CONFIG_PATH}"
REGISTRY_CONFIG_DIGEST="${REGISTRY_CONFIG_SHA256}"
REVERSE_PROXY_IMAGE_REFERENCE="${NGINX_IMAGE}"
REVISION_DATA_JSON="${REVISION_DATA_JSON}"
EOF
  )"

  env \
    --split-string "${environment}" \
    "${command}" \
    "${args[@]}" >/dev/null 2>&1
}

function get_swarm_state
{
  docker system info --format='{{ json . }}' |
    jq --raw-output '.Swarm.LocalNodeState' -
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
      pass insert \
        --force \
        --multiline \
        "${swarm_key_pass_id}" >/dev/null

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

function wait_for_networks_deletion
{
  if docker network ls --format '{{ .Name }}' |
    grep -E "^${NETWORK_NAME_INTERNAL}$" >/dev/null; then
    false
  fi
}

function start_registry_stack
{
  local compose_file="$1"
  local stack_name="$2"

  docker stack rm \
    "${stack_name}" >/dev/null 2>&1 ||
    true

  retry_until_success \
    "wait_for_networks_deletion" \
    wait_for_networks_deletion

  log_info "Building registry stack images..."

  run_with_compose_env \
    docker compose \
    --file "${compose_file}" \
    build

  log_info "Deploying registry stack..."

  run_with_compose_env \
    docker stack deploy \
    --compose-file "${compose_file}" \
    --prune \
    "${stack_name}"

  retry_until_success \
    "wait_for_rolling_update ${LOCAL_REGISTRY_HOST}" \
    wait_for_rolling_update "${LOCAL_REGISTRY_HOST}"
  retry_until_success \
    "ping_registry ${LOCAL_REGISTRY_HOST}" \
    ping_registry "${LOCAL_REGISTRY_HOST}"
  retry_until_success \
    "ping_registry ${MIRROR_REGISTRY_HOST}" \
    ping_registry "${MIRROR_REGISTRY_HOST}"

  log_info "Registry stack deployed successfully"
}

function wait_for_rolling_update
{
  local registry_host="$1"

  local scheme="https"
  local endpoint="_/revision"

  if is_git_repo; then
    curl --silent \
      "${scheme}://${registry_host}/${endpoint}" |
      grep "$(git rev-parse HEAD)"
  fi
}

function ping_registry
{
  local registry_host="$1"

  local scheme="https"
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

  LOCAL_SWARM_NODE_ID="$(get_local_node_id)"

  start_registry_stack \
    "${compose_file}" \
    "${stack_name}"
}

function get_configured_registry_mirrors
{
  docker system info --format '{{ json . }}' |
    jq --raw-output '.RegistryConfig.Mirrors[]' -
}

function ensure_docker_mirror_config
{
  local config_file="/etc/docker/daemon.json"
  local reg_mirrors="registry-mirrors"
  local url="https://${MIRROR_REGISTRY_HOST}"
  local output=""

  if ! get_configured_registry_mirrors | grep "${url}" >/dev/null; then
    if test -f "${config_file}"; then
      output="$(cat "${config_file}")"
    else
      output='{}'
    fi

    if ! echo "${output}" | grep "${url}" >/dev/null; then
      if test -f "${config_file}"; then
        local now
        now="$(date --utc +'%Y%m%d%H%M%S%N')"
        cp \
          "${config_file}" \
          "${THIS_SCRIPT_DIR}/$(basename "${config_file}")___${now}.bak"
      fi

      echo "${output}" |
        jq \
          --sort-keys \
          ". + { \"${reg_mirrors}\": [ \"${url}\" ] }" \
          - |
        sudo tee "${config_file}" >/dev/null

      sudo systemctl restart docker
    fi
  fi
}

function ensure_hosts_file
{
  ensure_host_is_in_etc_hosts_file \
    "${LOCAL_REGISTRY_HOST}" \
    "127.0.0.1"

  ensure_host_is_in_etc_hosts_file \
    "${MIRROR_REGISTRY_HOST}" \
    "127.0.0.1"
}

function select_mirror_registry_config
{
  if web_connection_working; then
    log_info "Mirror configuration: enabled"
    MIRROR_REGISTRY_CONFIG_SELECT="mirror_registry_config"
  else
    log_info "Mirror configuration: disabled"
    MIRROR_REGISTRY_CONFIG_SELECT="registry_config"
  fi
}

function main
{
  select_mirror_registry_config

  ensure_docker_mirror_config
  ensure_hosts_file
  ensure_docker_swarm_init
  ensure_local_docker_registry_is_running

  log_info "Success $(basename "$0")"
}

main
