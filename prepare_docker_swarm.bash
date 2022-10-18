set -euo pipefail
if command -v shopt &>/dev/null; then
  shopt -s inherit_errexit
fi
THIS_SCRIPT_DIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"
cd "${THIS_SCRIPT_DIR}"

source "${THIS_SCRIPT_DIR}/shell_script_imports/preamble.bash"

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

LOCAL_SERVICES_ROOT_DIR="${THIS_SCRIPT_DIR}/docker/swarm"
LOCAL_SWARM_NODE_ID="<___not_a_valid_id___>"

MAIN_NGINX_CONFIG_PATH="${LOCAL_SERVICES_ROOT_DIR}/reverse_proxy/main_nginx.conf.template"
MAIN_NGINX_CONFIG_SHA256="$(cat "${MAIN_NGINX_CONFIG_PATH}" |
  sha256 |
  take_first 8)"

GOGS_CONFIG="${LOCAL_SERVICES_ROOT_DIR}/git_frontend/app.ini"
GOGS_CONFIG_DIGEST="$(cat "${GOGS_CONFIG}" |
  sha256 |
  take_first 8)"

REGISTRY_CONFIG_PATH="${LOCAL_SERVICES_ROOT_DIR}/registry/config.yml"
REGISTRY_CONFIG_SHA256="$(cat "${REGISTRY_CONFIG_PATH}" |
  sha256 |
  take_first 8)"

GIT_FRONTEND_NGINX_CONFIG="${LOCAL_SERVICES_ROOT_DIR}/reverse_proxy/git_frontend_nginx.conf.template"
GIT_FRONTEND_NGINX_CONFIG_DIGEST="$(cat "${GIT_FRONTEND_NGINX_CONFIG}" |
  sha256 |
  take_first 8)"

PRIVATE_REGISTRY_NGINX_CONFIG="${LOCAL_SERVICES_ROOT_DIR}/reverse_proxy/private_registry_nginx.conf.template"
PRIVATE_REGISTRY_NGINX_CONFIG_DIGEST="$(cat "${PRIVATE_REGISTRY_NGINX_CONFIG}" |
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

GOGS_SECRET_KEY_e6403800="$(pass_show_or_generate "local_gogs_config_secret_key")"

HOST_TIMEZONE="$(current_timezone)"
DNS_IP_48zyazy8="192.168.49.200"

function generate_git_frontend_env
{
  cat <<EOF
DNS_IP_48zyazy8='${DNS_IP_48zyazy8}'
DNS_RESOLVER_IP='${DOCKER_DNS_RESOLVER_IP}'
DOMAIN_GIT_FRONTEND_df29c969='${DOMAIN_GIT_FRONTEND_df29c969}'
EXTERNAL_NETWORK_NAME='${EXTERNAL_NETWORK_NAME}'
GIT_FRONTEND_CONTEXT='${LOCAL_SERVICES_ROOT_DIR}/git_frontend/context'
GIT_FRONTEND_DOCKERFILE='${LOCAL_SERVICES_ROOT_DIR}/git_frontend/git_frontend.dockerfile'
GIT_FRONTEND_IMAGE_REFERENCE='${DOMAIN_DOCKER_REGISTRY_PRIVATE_a8a1ce1e}/gogs'
GIT_FRONTEND_LOCALHOST_CERT='${GIT_FRONTEND_LOCALHOST_CERT_PATH}'
GIT_FRONTEND_LOCALHOST_CERT_DIGEST='${GIT_FRONTEND_LOCALHOST_CERT_DIGEST}'
GIT_FRONTEND_LOCALHOST_KEY='${GIT_FRONTEND_LOCALHOST_KEY_PATH}'
GIT_FRONTEND_LOCALHOST_KEY_DIGEST='${GIT_FRONTEND_LOCALHOST_KEY_SECURE_DIGEST}'
GIT_FRONTEND_NGINX_CONFIG='${GIT_FRONTEND_NGINX_CONFIG}'
GIT_FRONTEND_NGINX_CONFIG_DIGEST='${GIT_FRONTEND_NGINX_CONFIG_DIGEST}'
GOGS_CONFIG='${GOGS_CONFIG}'
GOGS_CONFIG_DIGEST='${GOGS_CONFIG_DIGEST}'
GOGS_SECRET_KEY_e6403800='${GOGS_SECRET_KEY_e6403800}'
HOST_TIMEZONE='${HOST_TIMEZONE}'
LOCAL_NODE_ID='${LOCAL_SWARM_NODE_ID}'
REVERSE_PROXY_CONTEXT='${LOCAL_SERVICES_ROOT_DIR}/reverse_proxy/context'
REVERSE_PROXY_DOCKERFILE='${LOCAL_SERVICES_ROOT_DIR}/reverse_proxy/reverse_proxy.dockerfile'
REVERSE_PROXY_IMAGE_REFERENCE='${DOMAIN_DOCKER_REGISTRY_PRIVATE_a8a1ce1e}/nginx'
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
DOMAIN_DOCKER_REGISTRY_PRIVATE_a8a1ce1e='${DOMAIN_DOCKER_REGISTRY_PRIVATE_a8a1ce1e}'
EXTERNAL_NETWORK_NAME='${EXTERNAL_NETWORK_NAME}'
HOST_TIMEZONE='${HOST_TIMEZONE}'
LOCAL_NODE_ID='${LOCAL_SWARM_NODE_ID}'
PRIVATE_REGISTRY_CONFIG='${REGISTRY_CONFIG_PATH}'
PRIVATE_REGISTRY_CONFIG_DIGEST='${REGISTRY_CONFIG_SHA256}'
PRIVATE_REGISTRY_NGINX_CONFIG='${PRIVATE_REGISTRY_NGINX_CONFIG}'
PRIVATE_REGISTRY_NGINX_CONFIG_DIGEST='${PRIVATE_REGISTRY_NGINX_CONFIG_DIGEST}'
REGISTRY_CONTEXT='${LOCAL_SERVICES_ROOT_DIR}/registry/context'
REGISTRY_DOCKERFILE='${LOCAL_SERVICES_ROOT_DIR}/registry/registry.dockerfile'
REGISTRY_IMAGE_REFERENCE='${DOMAIN_DOCKER_REGISTRY_PRIVATE_a8a1ce1e}/registry'
REVERSE_PROXY_CONTEXT='${LOCAL_SERVICES_ROOT_DIR}/reverse_proxy/context'
REVERSE_PROXY_DOCKERFILE='${LOCAL_SERVICES_ROOT_DIR}/reverse_proxy/reverse_proxy.dockerfile'
REVERSE_PROXY_IMAGE_REFERENCE='${DOMAIN_DOCKER_REGISTRY_PRIVATE_a8a1ce1e}/nginx'
EOF
}

function generate_main_reverse_proxy_env
{
  cat <<EOF
DNS_IP_48zyazy8='${DNS_IP_48zyazy8}'
DNS_RESOLVER_IP='${DOCKER_DNS_RESOLVER_IP}'
DOCKER_REGISTRY_LOCAL_CERT='${DOCKER_REGISTRY_LOCAL_CERT_PATH}'
DOCKER_REGISTRY_LOCAL_CERT_DIGEST='${DOCKER_REGISTRY_LOCAL_CERT_DIGEST}'
DOCKER_REGISTRY_LOCAL_KEY='${DOCKER_REGISTRY_LOCAL_KEY_PATH}'
DOCKER_REGISTRY_LOCAL_KEY_DIGEST='${DOCKER_REGISTRY_LOCAL_KEY_SECURE_DIGEST}'
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
REVERSE_PROXY_CONTEXT='${LOCAL_SERVICES_ROOT_DIR}/reverse_proxy/context'
REVERSE_PROXY_DOCKERFILE='${LOCAL_SERVICES_ROOT_DIR}/reverse_proxy/reverse_proxy.dockerfile'
REVERSE_PROXY_IMAGE_REFERENCE='${DOMAIN_DOCKER_REGISTRY_PRIVATE_a8a1ce1e}/nginx'
REVISION_DATA_JSON='${REVISION_DATA_JSON}'
EOF
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

function start_registries
{
  start_docker_stack \
    generate_registries_env \
    "${THIS_SCRIPT_DIR}/local_docker_registry.json" \
    "${DOCKER_REGISTRY_STACK_NAME}"
}

function start_git_frontend
{
  bash "${LOCAL_SERVICES_ROOT_DIR}/git_frontend/prepare_build_context.bash"

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

function main
{
  EXTERNAL_NETWORK_NAME="$(bash "${THIS_SCRIPT_DIR}/create_external_docker_network.bash")"
  LOCAL_SWARM_NODE_ID="$(get_local_node_id)"

  start_registries &
  start_git_frontend &
  start_main_reverse_proxy &
  wait

  log_info "Success $(basename "$0")"
}

main
