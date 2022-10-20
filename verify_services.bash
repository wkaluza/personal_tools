set -euo pipefail
if command -v shopt &>/dev/null; then
  shopt -s inherit_errexit
fi
THIS_SCRIPT_DIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"
cd "${THIS_SCRIPT_DIR}"

source "${THIS_SCRIPT_DIR}/shell_script_imports/preamble.bash"

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

function test_dns_from_docker
{
  local name="$1"
  local host="$2"
  local ip="$3"

  docker exec -it "${name}" \
    host "${host}" |
    grep "${ip}"
}

function test_dns_from_k8s
{
  local name="$1"
  local namespace="$2"
  local host="$3"
  local ip="$4"

  kubectl exec \
    --namespace "${namespace}" \
    "${name}" -- \
    host "${host}" |
    grep "${ip}"
}

function test_dns_docker
{
  local test_ip="$1"

  local test_name="startup-test-8k4zscuq"

  log_info "Testing DNS from docker..."
  retry_until_success \
    "test_dns_from_docker" \
    test_dns_from_docker \
    "${test_name}" \
    "${DOMAIN_STARTUP_TEST_dmzrfohk}" \
    "${test_ip}"

  docker rm --force "${test_name}" >/dev/null
}

function test_dns_k8s
{
  local test_ip="$1"

  local test_name="startup-test-c2kjkrm5"
  local namespace="default"

  log_info "Testing DNS from cluster..."
  retry_until_success \
    "test_dns_from_k8s" \
    test_dns_from_k8s \
    "${test_name}" \
    "${namespace}" \
    "${DOMAIN_STARTUP_TEST_dmzrfohk}" \
    "${test_ip}"

  kubectl delete \
    pod \
    --namespace "${namespace}" \
    "${test_name}" >/dev/null
}

function ensure_all_k8s_pods_are_running
{
  log_info "Waiting for full k8s pod readiness..."

  kubectl wait pod \
    --all \
    --all-namespaces \
    --for="condition=Ready" \
    --timeout="60s" >/dev/null
}

function main
{
  local test_ip="123.132.213.231"

  ensure_services_are_running
  ensure_connection_to_swarm

  ensure_all_k8s_pods_are_running

  test_dns_docker \
    "${test_ip}"
  test_dns_k8s \
    "${test_ip}"

  log_info "Success $(basename "$0")"
}

main
