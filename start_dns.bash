set -euo pipefail
if command -v shopt &>/dev/null; then
  shopt -s inherit_errexit
fi
THIS_SCRIPT_DIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"
cd "${THIS_SCRIPT_DIR}"

source "${THIS_SCRIPT_DIR}/shell_script_imports/preamble.bash"

LOCAL_SERVICES_ROOT_DIR="${THIS_SCRIPT_DIR}/docker/swarm"

function build_and_push_dns_test
{
  local dnstools_tag="$1"

  local dnstools_service_dir="${LOCAL_SERVICES_ROOT_DIR}/dns_tools"

  docker build \
    --file "${dnstools_service_dir}/dns_tools.dockerfile" \
    --tag "${dnstools_tag}" \
    "${dnstools_service_dir}/context"

  docker push \
    "${dnstools_tag}"
}

function start_docker_dns_test
{
  local dnstools_tag="$1"
  local dns_ip="$2"

  local test_name="startup-test-8k4zscuq"

  docker run \
    --detach \
    --name "${test_name}" \
    --network "minikube" \
    --restart=always \
    --dns "${dns_ip}" \
    "${dnstools_tag}" \
    sleep infinity
}

function start_k8s_dns_test
{
  local dnstools_tag="$1"

  local test_name="startup-test-c2kjkrm5"
  local namespace="default"

  kubectl run \
    --image "${dnstools_tag}" \
    --restart=Always \
    --namespace "${namespace}" \
    "${test_name}" \
    -- \
    sleep infinity

  kubectl wait pod \
    --namespace "${namespace}" \
    "${test_name}" \
    --for="condition=Ready" >/dev/null
}

function build_and_push_dns
{
  local dns_tag="$1"

  local dns_service_dir="${LOCAL_SERVICES_ROOT_DIR}/dns"

  bash "${dns_service_dir}/prepare_build_context.bash"

  docker build \
    --file "${dns_service_dir}/dns.dockerfile" \
    --tag "${dns_tag}" \
    "${dns_service_dir}/context"

  docker push \
    "${dns_tag}"
}

function start_dns
{
  local dns_tag="$1"
  local dns_ip="$2"

  local dns_name="dns-container-wld1bdxc"

  docker run \
    --detach \
    --name "${dns_name}" \
    --network "minikube" \
    --ip "${dns_ip}" \
    "${dns_tag}" \
    -conf /docker/corefile
}

function main
{
  local dns_ip="192.168.49.200"
  local dnstools_tag="private.docker.localhost/dnstesting:1"
  local dns_tag="private.docker.localhost/dns:1"

  build_and_push_dns \
    "${dns_tag}" >/dev/null &
  build_and_push_dns_test \
    "${dnstools_tag}" >/dev/null &
  wait

  start_dns \
    "${dns_tag}" \
    "${dns_ip}" >/dev/null

  start_docker_dns_test \
    "${dnstools_tag}" \
    "${dns_ip}" >/dev/null

  start_k8s_dns_test \
    "${dnstools_tag}" >/dev/null

  log_info "Success $(basename "$0")"
}

main
