set -euo pipefail
if command -v shopt &>/dev/null; then
  shopt -s inherit_errexit
fi
THIS_SCRIPT_DIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"
cd "${THIS_SCRIPT_DIR}"

source "${THIS_SCRIPT_DIR}/shell_script_imports/common.bash"
source "${THIS_SCRIPT_DIR}/shell_script_imports/logging.bash"
source "${THIS_SCRIPT_DIR}/shell_script_imports/git_helpers.bash"
source "${THIS_SCRIPT_DIR}/shell_script_imports/gogs_helpers.bash"

source <(cat "${THIS_SCRIPT_DIR}/local_domains.json" |
  jq '. | to_entries' - |
  jq '. | map( "\(.key)=\"\(.value)\"" )' - |
  jq --raw-output '. | .[]' - |
  sort)

DOCKER_REGISTRY_STACK_NAME="local_registry_stack"
REVERSE_PROXY_STACK_NAME="local_reverse_proxy_stack"
GIT_FRONTEND_STACK_NAME="local_git_frontend_stack"

EXTERNAL_NETWORK_NAME="<___not_a_real_network___>"

DOCKER_DNS_RESOLVER_IP="127.0.0.11"

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

REVISION_DATA_JSON="$(generate_revision_data)"

DOCKER_REGISTRY_ROOT_DIR="${THIS_SCRIPT_DIR}/docker_registry"
LOCAL_SWARM_NODE_ID="<___not_a_valid_id___>"

MAIN_NGINX_CONFIG_PATH="${DOCKER_REGISTRY_ROOT_DIR}/reverse_proxy/main_nginx.conf.template"
MAIN_NGINX_CONFIG_SHA256="$(cat "${MAIN_NGINX_CONFIG_PATH}" |
  sha256 |
  take_first 8)"

GOGS_CONFIG="${DOCKER_REGISTRY_ROOT_DIR}/git_frontend/app.ini"
GOGS_CONFIG_DIGEST="$(cat "${GOGS_CONFIG}" |
  sha256 |
  take_first 8)"

REGISTRY_CONFIG_PATH="${DOCKER_REGISTRY_ROOT_DIR}/registry/config.yml"
REGISTRY_CONFIG_SHA256="$(cat "${REGISTRY_CONFIG_PATH}" |
  sha256 |
  take_first 8)"

MIRROR_CONFIG_PATH="${DOCKER_REGISTRY_ROOT_DIR}/registry/config_mirror.yml"
MIRROR_CONFIG_SHA256="$(cat "${MIRROR_CONFIG_PATH}" |
  sha256 |
  take_first 8)"

PRIVATE_REGISTRY_NGINX_CONFIG="${DOCKER_REGISTRY_ROOT_DIR}/reverse_proxy/private_registry_nginx.conf.template"
PRIVATE_REGISTRY_NGINX_CONFIG_DIGEST="$(cat "${PRIVATE_REGISTRY_NGINX_CONFIG}" |
  sha256 |
  take_first 8)"

MIRROR_REGISTRY_NGINX_CONFIG="${DOCKER_REGISTRY_ROOT_DIR}/reverse_proxy/mirror_registry_nginx.conf.template"
MIRROR_REGISTRY_NGINX_CONFIG_DIGEST="$(cat "${MIRROR_REGISTRY_NGINX_CONFIG}" |
  sha256 |
  take_first 8)"

CERTS_DIR="${HOME}/.wk_certificates___"

DOCKER_REGISTRY_LOCAL_CERT_PATH="${CERTS_DIR}/${DOMAIN_DOCKER_REGISTRY_PRIVATE_a8a1ce1e}.pem"
DOCKER_REGISTRY_LOCAL_CERT_DIGEST="$(cat "${DOCKER_REGISTRY_LOCAL_CERT_PATH}" |
  sha256 |
  take_first 8)"
DOCKER_REGISTRY_LOCAL_KEY_PATH="${CERTS_DIR}/${DOMAIN_DOCKER_REGISTRY_PRIVATE_a8a1ce1e}.secret"
DOCKER_REGISTRY_LOCAL_KEY_SECURE_DIGEST="$(cat "${DOCKER_REGISTRY_LOCAL_KEY_PATH}" |
  encrypt_deterministically "${DOCKER_REGISTRY_LOCAL_KEY_PATH}" |
  sha256 |
  take_first 8)"

DOCKER_REGISTRY_MIRROR_CERT_PATH="${CERTS_DIR}/${DOMAIN_DOCKER_REGISTRY_MIRROR_f334ec4f}.pem"
DOCKER_REGISTRY_MIRROR_CERT_DIGEST="$(cat "${DOCKER_REGISTRY_MIRROR_CERT_PATH}" |
  sha256 |
  take_first 8)"
DOCKER_REGISTRY_MIRROR_KEY_PATH="${CERTS_DIR}/${DOMAIN_DOCKER_REGISTRY_MIRROR_f334ec4f}.secret"
DOCKER_REGISTRY_MIRROR_KEY_SECURE_DIGEST="$(cat "${DOCKER_REGISTRY_MIRROR_KEY_PATH}" |
  encrypt_deterministically "${DOCKER_REGISTRY_MIRROR_KEY_PATH}" |
  sha256 |
  take_first 8)"

MAIN_LOCALHOST_CERT_PATH="${CERTS_DIR}/${DOMAIN_MAIN_REVERSE_PROXY_cab92795}.pem"
MAIN_LOCALHOST_CERT_DIGEST="$(cat "${MAIN_LOCALHOST_CERT_PATH}" |
  sha256 |
  take_first 8)"
MAIN_LOCALHOST_KEY_PATH="${CERTS_DIR}/${DOMAIN_MAIN_REVERSE_PROXY_cab92795}.secret"
MAIN_LOCALHOST_KEY_SECURE_DIGEST="$(cat "${MAIN_LOCALHOST_KEY_PATH}" |
  encrypt_deterministically "${MAIN_LOCALHOST_KEY_PATH}" |
  sha256 |
  take_first 8)"

GIT_FRONTEND_LOCALHOST_CERT_PATH="${CERTS_DIR}/${DOMAIN_GIT_FRONTEND_df29c969}.pem"
GIT_FRONTEND_LOCALHOST_CERT_DIGEST="$(cat "${GIT_FRONTEND_LOCALHOST_CERT_PATH}" |
  sha256 |
  take_first 8)"
GIT_FRONTEND_LOCALHOST_KEY_PATH="${CERTS_DIR}/${DOMAIN_GIT_FRONTEND_df29c969}.secret"
GIT_FRONTEND_LOCALHOST_KEY_SECURE_DIGEST="$(cat "${GIT_FRONTEND_LOCALHOST_KEY_PATH}" |
  encrypt_deterministically "${GIT_FRONTEND_LOCALHOST_KEY_PATH}" |
  sha256 |
  take_first 8)"

MIRROR_REGISTRY_CONFIG_SELECT=""
GOGS_SECRET_KEY_e6403800="$(pass_show_or_generate "local_gogs_config_secret_key")"

HOST_TIMEZONE="$(current_timezone)"

function generate_git_frontend_env
{
  cat <<EOF
DOMAIN_GIT_FRONTEND_df29c969='${DOMAIN_GIT_FRONTEND_df29c969}'
EXTERNAL_NETWORK_NAME='${EXTERNAL_NETWORK_NAME}'
GIT_FRONTEND_CONTEXT='${DOCKER_REGISTRY_ROOT_DIR}/git_frontend/context'
GIT_FRONTEND_DOCKERFILE='${DOCKER_REGISTRY_ROOT_DIR}/git_frontend/git_frontend.dockerfile'
GIT_FRONTEND_IMAGE_REFERENCE='${DOMAIN_DOCKER_REGISTRY_PRIVATE_a8a1ce1e}/gogs'
GOGS_CONFIG='${GOGS_CONFIG}'
GOGS_CONFIG_DIGEST='${GOGS_CONFIG_DIGEST}'
GOGS_SECRET_KEY_e6403800='${GOGS_SECRET_KEY_e6403800}'
HOST_TIMEZONE='${HOST_TIMEZONE}'
LOCAL_NODE_ID='${LOCAL_SWARM_NODE_ID}'
EOF
}

function generate_registries_env
{
  cat <<EOF
DNS_RESOLVER_IP='${DOCKER_DNS_RESOLVER_IP}'
DOCKER_REGISTRY_LOCAL_CERT='${DOCKER_REGISTRY_LOCAL_CERT_PATH}'
DOCKER_REGISTRY_LOCAL_CERT_DIGEST='${DOCKER_REGISTRY_LOCAL_CERT_DIGEST}'
DOCKER_REGISTRY_LOCAL_KEY='${DOCKER_REGISTRY_LOCAL_KEY_PATH}'
DOCKER_REGISTRY_LOCAL_KEY_DIGEST='${DOCKER_REGISTRY_LOCAL_KEY_SECURE_DIGEST}'
DOCKER_REGISTRY_MIRROR_CERT='${DOCKER_REGISTRY_MIRROR_CERT_PATH}'
DOCKER_REGISTRY_MIRROR_CERT_DIGEST='${DOCKER_REGISTRY_MIRROR_CERT_DIGEST}'
DOCKER_REGISTRY_MIRROR_KEY='${DOCKER_REGISTRY_MIRROR_KEY_PATH}'
DOCKER_REGISTRY_MIRROR_KEY_DIGEST='${DOCKER_REGISTRY_MIRROR_KEY_SECURE_DIGEST}'
DOMAIN_DOCKER_REGISTRY_MIRROR_f334ec4f='${DOMAIN_DOCKER_REGISTRY_MIRROR_f334ec4f}'
DOMAIN_DOCKER_REGISTRY_PRIVATE_a8a1ce1e='${DOMAIN_DOCKER_REGISTRY_PRIVATE_a8a1ce1e}'
EXTERNAL_NETWORK_NAME='${EXTERNAL_NETWORK_NAME}'
HOST_TIMEZONE='${HOST_TIMEZONE}'
LOCAL_NODE_ID='${LOCAL_SWARM_NODE_ID}'
MIRROR_REGISTRY_CONFIG='${MIRROR_CONFIG_PATH}'
MIRROR_REGISTRY_CONFIG_DIGEST='${MIRROR_CONFIG_SHA256}'
MIRROR_REGISTRY_CONFIG_SELECT='${MIRROR_REGISTRY_CONFIG_SELECT}'
MIRROR_REGISTRY_NGINX_CONFIG='${MIRROR_REGISTRY_NGINX_CONFIG}'
MIRROR_REGISTRY_NGINX_CONFIG_DIGEST='${MIRROR_REGISTRY_NGINX_CONFIG_DIGEST}'
PRIVATE_REGISTRY_CONFIG='${REGISTRY_CONFIG_PATH}'
PRIVATE_REGISTRY_CONFIG_DIGEST='${REGISTRY_CONFIG_SHA256}'
PRIVATE_REGISTRY_NGINX_CONFIG='${PRIVATE_REGISTRY_NGINX_CONFIG}'
PRIVATE_REGISTRY_NGINX_CONFIG_DIGEST='${PRIVATE_REGISTRY_NGINX_CONFIG_DIGEST}'
REGISTRY_CONTEXT='${DOCKER_REGISTRY_ROOT_DIR}/registry/context'
REGISTRY_DOCKERFILE='${DOCKER_REGISTRY_ROOT_DIR}/registry/registry.dockerfile'
REGISTRY_IMAGE_REFERENCE='${DOMAIN_DOCKER_REGISTRY_PRIVATE_a8a1ce1e}/registry'
REVERSE_PROXY_CONTEXT='${DOCKER_REGISTRY_ROOT_DIR}/reverse_proxy/context'
REVERSE_PROXY_DOCKERFILE='${DOCKER_REGISTRY_ROOT_DIR}/reverse_proxy/reverse_proxy.dockerfile'
REVERSE_PROXY_IMAGE_REFERENCE='${DOMAIN_DOCKER_REGISTRY_PRIVATE_a8a1ce1e}/nginx'
EOF
}

function generate_main_reverse_proxy_env
{
  cat <<EOF
DNS_RESOLVER_IP='${DOCKER_DNS_RESOLVER_IP}'
DOCKER_REGISTRY_LOCAL_CERT='${DOCKER_REGISTRY_LOCAL_CERT_PATH}'
DOCKER_REGISTRY_LOCAL_CERT_DIGEST='${DOCKER_REGISTRY_LOCAL_CERT_DIGEST}'
DOCKER_REGISTRY_LOCAL_KEY='${DOCKER_REGISTRY_LOCAL_KEY_PATH}'
DOCKER_REGISTRY_LOCAL_KEY_DIGEST='${DOCKER_REGISTRY_LOCAL_KEY_SECURE_DIGEST}'
DOCKER_REGISTRY_MIRROR_CERT='${DOCKER_REGISTRY_MIRROR_CERT_PATH}'
DOCKER_REGISTRY_MIRROR_CERT_DIGEST='${DOCKER_REGISTRY_MIRROR_CERT_DIGEST}'
DOCKER_REGISTRY_MIRROR_KEY='${DOCKER_REGISTRY_MIRROR_KEY_PATH}'
DOCKER_REGISTRY_MIRROR_KEY_DIGEST='${DOCKER_REGISTRY_MIRROR_KEY_SECURE_DIGEST}'
DOMAIN_DOCKER_REGISTRY_MIRROR_f334ec4f='${DOMAIN_DOCKER_REGISTRY_MIRROR_f334ec4f}'
DOMAIN_DOCKER_REGISTRY_PRIVATE_a8a1ce1e='${DOMAIN_DOCKER_REGISTRY_PRIVATE_a8a1ce1e}'
DOMAIN_GIT_FRONTEND_df29c969='${DOMAIN_GIT_FRONTEND_df29c969}'
DOMAIN_MAIN_REVERSE_PROXY_cab92795='${DOMAIN_MAIN_REVERSE_PROXY_cab92795}'
EXTERNAL_NETWORK_NAME='${EXTERNAL_NETWORK_NAME}'
GIT_FRONTEND_LOCALHOST_CERT='${GIT_FRONTEND_LOCALHOST_CERT_PATH}'
GIT_FRONTEND_LOCALHOST_CERT_DIGEST='${GIT_FRONTEND_LOCALHOST_CERT_DIGEST}'
GIT_FRONTEND_LOCALHOST_KEY='${GIT_FRONTEND_LOCALHOST_KEY_PATH}'
GIT_FRONTEND_LOCALHOST_KEY_DIGEST='${GIT_FRONTEND_LOCALHOST_KEY_SECURE_DIGEST}'
HOST_TIMEZONE='${HOST_TIMEZONE}'
LOCAL_NODE_ID='${LOCAL_SWARM_NODE_ID}'
MAIN_LOCALHOST_CERT='${MAIN_LOCALHOST_CERT_PATH}'
MAIN_LOCALHOST_CERT_DIGEST='${MAIN_LOCALHOST_CERT_DIGEST}'
MAIN_LOCALHOST_KEY='${MAIN_LOCALHOST_KEY_PATH}'
MAIN_LOCALHOST_KEY_DIGEST='${MAIN_LOCALHOST_KEY_SECURE_DIGEST}'
MAIN_NGINX_CONFIG='${MAIN_NGINX_CONFIG_PATH}'
MAIN_NGINX_CONFIG_DIGEST='${MAIN_NGINX_CONFIG_SHA256}'
REVERSE_PROXY_CONTEXT='${DOCKER_REGISTRY_ROOT_DIR}/reverse_proxy/context'
REVERSE_PROXY_DOCKERFILE='${DOCKER_REGISTRY_ROOT_DIR}/reverse_proxy/reverse_proxy.dockerfile'
REVERSE_PROXY_IMAGE_REFERENCE='${DOMAIN_DOCKER_REGISTRY_PRIVATE_a8a1ce1e}/nginx'
REVISION_DATA_JSON='${REVISION_DATA_JSON}'
EOF
}

function run_with_env
{
  local env_factory="$1"
  local command="$2"
  local args=("${@:3}")

  env \
    --split-string "$(${env_factory} | tr '\n' ' ')" \
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

    docker swarm init \
      --advertise-addr "127.0.0.1" \
      --autolock |
      grep "${swarm_key_magic_prefix}" |
      sed -E "s/^.*(${swarm_key_magic_prefix}.*)$/\1/" |
      store_in_pass "${swarm_key_pass_id}"

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

function stack_internal_networks
{
  local stack_name="$1"
  local compose_file="$2"

  cat "${compose_file}" |
    jq --raw-output '.networks | keys | .[]' - |
    grep "internal" |
    awk "{ print \"${stack_name}_\" \$0 }" |
    sort
}

function wait_for_networks_deletion
{
  local stack_name="$1"
  local compose_file="$2"

  for network_name in $(stack_internal_networks \
    "${stack_name}" \
    "${compose_file}"); do
    if docker network ls --format '{{ .Name }}' |
      grep -E "^${network_name}$" >/dev/null; then
      false
    fi
  done
}

function start_docker_stack
{
  local env_factory="$1"
  local compose_file="$2"
  local stack_name="$3"

  docker stack rm \
    "${stack_name}" >/dev/null 2>&1 ||
    true

  retry_until_success \
    "wait_for_networks_deletion" \
    wait_for_networks_deletion \
    "${stack_name}" \
    "${compose_file}"

  log_info "Building ${stack_name} images..."

  run_with_env \
    "${env_factory}" \
    docker compose \
    --file "${compose_file}" \
    build

  log_info "Deploying ${stack_name}..."

  run_with_env \
    "${env_factory}" \
    docker stack deploy \
    --compose-file "${compose_file}" \
    --prune \
    "${stack_name}"

  log_info "Stack ${stack_name} deployed successfully"
}

function push_stack_images
{
  local env_factory="$1"
  local compose_file="$2"
  local stack_name="$3"

  log_info "Pushing ${stack_name} images..."

  run_with_env \
    "${env_factory}" \
    docker compose \
    --file "${compose_file}" \
    push

  log_info "Stack ${stack_name} pushed successfully"
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

function ping_gogs
{
  local host="$1"

  local scheme="https"
  local endpoint="api/v1/users/search"

  local ok
  ok="$(curl --silent \
    "${scheme}://${host}/${endpoint}?q=arbitrarysearchphrase" |
    jq '.ok' -)"

  if [[ "${ok}" != "true" ]]; then
    false
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

function remove_stale_gogs_ssh_key
{
  ssh-keygen \
    -f "${HOME}/.ssh/known_hosts" \
    -R "${DOMAIN_GIT_FRONTEND_df29c969}" >/dev/null 2>&1 ||
    true
}

function ensure_gogs_user_configured
{
  local username="$1"
  local pass_gogs_password_id="local_gogs_password_${username}"
  local token_name="local_gogs_token_${username}"
  local pass_gogs_token_id="${token_name}"
  local ssh_key_name="ssh_key_${username}"

  local password
  password="$(pass_show_or_generate "${pass_gogs_password_id}")"

  local primary_key_fingerprint="174C9368811039C87F0C806A896572D1E78ED6A7"

  if gogs_get_single_user \
    "${DOMAIN_GIT_FRONTEND_df29c969}" \
    "${username}" >/dev/null 2>&1; then
    log_info "Gogs user ${username} exists"
  else
    log_info "Creating gogs user ${username}..."

    gogs_docker_cli_create_admin_user \
      "${GIT_FRONTEND_STACK_NAME}" \
      "/app/gogs/gogs" \
      "wkaluza@protonmail.com" \
      "${username}" \
      "${password}" >/dev/null 2>&1

    # Fresh gogs install
    remove_stale_gogs_ssh_key
  fi

  if gogs_list_token_names \
    "${DOMAIN_GIT_FRONTEND_df29c969}" \
    "${username}" \
    "${password}" |
    grep -E "^${token_name}$" >/dev/null; then
    log_info "Gogs token exists"
  else
    log_info "Creating gogs token..."

    gogs_generate_token \
      "${DOMAIN_GIT_FRONTEND_df29c969}" \
      "${username}" \
      "${password}" \
      "${token_name}" |
      store_in_pass "${pass_gogs_token_id}"
  fi

  local token_value
  token_value="$(pass show "${pass_gogs_token_id}")"
  local auth_header="Authorization: token ${token_value}"

  if ! gogs_ssh_key_exists \
    "${DOMAIN_GIT_FRONTEND_df29c969}" \
    "${username}" \
    "${ssh_key_name}" \
    "${auth_header}" >/dev/null; then
    log_info "Uploading SSH key to gogs..."
    gogs_create_ssh_key \
      "${DOMAIN_GIT_FRONTEND_df29c969}" \
      "${ssh_key_name}" \
      "$(gpg --export-ssh-key "${primary_key_fingerprint}")" \
      "${auth_header}"
  else
    log_info "Gogs SSH key already uploaded"
  fi
}

function ensure_services_are_running
{
  retry_until_success \
    "wait_for_rolling_update ${DOMAIN_MAIN_REVERSE_PROXY_cab92795}" \
    wait_for_rolling_update "${DOMAIN_MAIN_REVERSE_PROXY_cab92795}"

  retry_until_success \
    "ping_registry ${DOMAIN_DOCKER_REGISTRY_PRIVATE_a8a1ce1e}" \
    ping_registry "${DOMAIN_DOCKER_REGISTRY_PRIVATE_a8a1ce1e}"

  retry_until_success \
    "ping_registry ${DOMAIN_DOCKER_REGISTRY_MIRROR_f334ec4f}" \
    ping_registry "${DOMAIN_DOCKER_REGISTRY_MIRROR_f334ec4f}"

  retry_until_success \
    "ping_gogs ${DOMAIN_GIT_FRONTEND_df29c969}" \
    ping_gogs "${DOMAIN_GIT_FRONTEND_df29c969}"
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
  local url="https://${DOMAIN_DOCKER_REGISTRY_MIRROR_f334ec4f}"
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

function start_registries
{
  start_docker_stack \
    generate_registries_env \
    "${THIS_SCRIPT_DIR}/local_docker_registry.json" \
    "${DOCKER_REGISTRY_STACK_NAME}"
}

function start_git_frontend
{
  start_docker_stack \
    generate_git_frontend_env \
    "${THIS_SCRIPT_DIR}/local_git_frontend.json" \
    "${GIT_FRONTEND_STACK_NAME}"
}

function start_main_reverse_proxy
{
  start_docker_stack \
    generate_main_reverse_proxy_env \
    "${THIS_SCRIPT_DIR}/local_reverse_proxy.json" \
    "${REVERSE_PROXY_STACK_NAME}"
}

function push_stack_images_registries
{
  push_stack_images \
    generate_registries_env \
    "${THIS_SCRIPT_DIR}/local_docker_registry.json" \
    "${DOCKER_REGISTRY_STACK_NAME}"
}

function push_stack_images_git_frontend
{
  push_stack_images \
    generate_git_frontend_env \
    "${THIS_SCRIPT_DIR}/local_git_frontend.json" \
    "${GIT_FRONTEND_STACK_NAME}"
}

function push_stack_images_main_reverse_proxy
{
  push_stack_images \
    generate_main_reverse_proxy_env \
    "${THIS_SCRIPT_DIR}/local_reverse_proxy.json" \
    "${REVERSE_PROXY_STACK_NAME}"
}

function main
{
  local username="wkaluza"
  local repo_name="infrastructure"
  local token
  token="$(pass show "local_gogs_token_${username}")"
  local auth_header="Authorization: token ${token}"

  select_mirror_registry_config

  ensure_docker_mirror_config
  ensure_docker_swarm_init

  EXTERNAL_NETWORK_NAME="$(bash "${THIS_SCRIPT_DIR}/create_external_docker_network.bash")"
  LOCAL_SWARM_NODE_ID="$(get_local_node_id)"

  start_registries &
  start_git_frontend &
  start_main_reverse_proxy &
  wait

  ensure_services_are_running

  push_stack_images_registries &
  push_stack_images_git_frontend &
  push_stack_images_main_reverse_proxy &

  ensure_gogs_user_configured \
    "${username}" &
  wait

  if ! gogs_check_repo_exists \
    "${DOMAIN_GIT_FRONTEND_df29c969}" \
    "${username}" \
    "${repo_name}" \
    "${auth_header}"; then
    log_info "Creating repository ${repo_name}..."
    bash "${THIS_SCRIPT_DIR}/generate_infrastructure.bash"
  fi

  log_info "Success $(basename "$0")"
}

main
