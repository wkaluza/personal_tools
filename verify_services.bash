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

function wait_for_rolling_update
{
  local host="$1"

  local scheme="https"
  local endpoint="_/revision"

  if is_git_repo; then
    curl --silent \
      "${scheme}://${host}/${endpoint}" |
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

function ping_hub_from_cluster
{
  local scheme="https"
  local endpoint="v2/_catalog"

  minikube ssh -- \
    curl --silent \
    "${scheme}://${DOMAIN_DOCKER_REGISTRY_PRIVATE_a8a1ce1e}/${endpoint}" |
    grep "repositories"
}

function ensure_connection_to_swarm
{
  log_info "Testing connection to swarm..."

  retry_until_success \
    "ping_hub_from_cluster" \
    ping_hub_from_cluster

  log_info "Swarm connected"
}

function main
{
  ensure_services_are_running
  ensure_connection_to_swarm

  log_info "Success $(basename "$0")"
}

main
