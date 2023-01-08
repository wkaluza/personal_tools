set -euo pipefail
if command -v shopt &>/dev/null; then
  shopt -s inherit_errexit
fi
THIS_SCRIPT_DIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"
cd "${THIS_SCRIPT_DIR}"

source "${THIS_SCRIPT_DIR}/shell_script_imports/preamble.bash"

DNS_IP_48zyazy8="192.168.49.200"
DNS_TEST_STACK_NAME="local_dns_test_stack"
DNS_TEST_IMAGE_REFERENCE="${DOMAIN_DOCKER_REGISTRY_PRIVATE_a8a1ce1e}/app/dns_tools:1"
LOCAL_SWARM_NODE_ID="$(get_local_node_id)"

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

function ping_hub
{
  local host="$1"

  local scheme="https"
  local endpoint="_/healthcheck"

  curl --silent \
    "${scheme}://${host}/${endpoint}" |
    grep "HEALTHY"
}

function ensure_services_are_running
{
  retry_until_success \
    "ping_hub ${DOMAIN_MAIN_REVERSE_PROXY_cab92795}" \
    ping_hub "${DOMAIN_MAIN_REVERSE_PROXY_cab92795}"

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
  local id="$1"
  local host="$2"
  local ip="$3"

  if ! docker exec -it "${id}" \
    host "${host}" |
    quiet grep "${ip}"; then
    return 1
  fi
}

function test_dns_from_k8s
{
  local name="$1"
  local namespace="$2"
  local host="$3"
  local ip="$4"

  if ! kubectl exec \
    --namespace "${namespace}" \
    "${name}" -- \
    host "${host}" |
    quiet grep "${ip}"; then
    return 1
  fi
}

function test_dns_docker
{
  local test_ip="$1"

  local test_id
  test_id="$(list_stack_services "${DNS_TEST_STACK_NAME}" |
    for_each list_service_tasks |
    for_each list_task_containers |
    head -n+1)"

  log_info "Testing DNS from docker..."
  retry_until_success \
    "test_dns_from_docker" \
    test_dns_from_docker \
    "${test_id}" \
    "${DOMAIN_STARTUP_TEST_dmzrfohk}" \
    "${test_ip}"

  quiet docker stack rm "${DNS_TEST_STACK_NAME}"
}

function test_dns_k8s
{
  local test_name="$1"
  local namespace="$2"
  local test_ip="$3"

  log_info "Testing DNS from cluster..."
  retry_until_success \
    "test_dns_from_k8s" \
    test_dns_from_k8s \
    "${test_name}" \
    "${namespace}" \
    "${DOMAIN_STARTUP_TEST_dmzrfohk}" \
    "${test_ip}"

  quiet kubectl delete \
    pod \
    --namespace "${namespace}" \
    "${test_name}"
}

function ensure_all_k8s_pods_are_running
{
  log_info "Waiting for full k8s pod readiness..."

  quiet kubectl wait pod \
    --all \
    --all-namespaces \
    --for="condition=Ready" \
    --timeout="60s"
}

function generate_dns_test_env
{
  cat <<EOF
DNS_IP_48zyazy8='${DNS_IP_48zyazy8}'
DNS_TEST_IMAGE_REFERENCE='${DNS_TEST_IMAGE_REFERENCE}'
LOCAL_NODE_ID='${LOCAL_SWARM_NODE_ID}'
EOF
}

function start_docker_dns_test
{
  start_docker_stack \
    generate_dns_test_env \
    "${THIS_SCRIPT_DIR}/local_dns_test.json" \
    "${DNS_TEST_STACK_NAME}"

  connect_stack_containers_to_network \
    "minikube" \
    "auto" \
    "wk.connect.cluster-cnr8lm0i" \
    "true" \
    "${DNS_TEST_STACK_NAME}"
}

function start_k8s_dns_test
{
  local test_name="$1"
  local namespace="$2"

  quiet kubectl run \
    --image "${DNS_TEST_IMAGE_REFERENCE}" \
    --restart=Always \
    --namespace "${namespace}" \
    "${test_name}" \
    -- \
    sleep infinity

  quiet kubectl wait pod \
    --namespace "${namespace}" \
    "${test_name}" \
    --for="condition=Ready" \
    --timeout="60s"
}

function main
{
  local test_ip="123.132.213.231"
  local k8s_dns_test_name="startup-test-c2kjkrm5"
  local k8s_dns_test_namespace="default"

  ensure_services_are_running
  ensure_connection_to_swarm

  ensure_all_k8s_pods_are_running

  start_docker_dns_test
  start_k8s_dns_test \
    "${k8s_dns_test_name}" \
    "${k8s_dns_test_namespace}"

  test_dns_docker \
    "${test_ip}"
  test_dns_k8s \
    "${k8s_dns_test_name}" \
    "${k8s_dns_test_namespace}" \
    "${test_ip}"

  log_info "Success $(basename "$0")"
}

main
