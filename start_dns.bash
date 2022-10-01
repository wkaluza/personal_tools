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

function build_and_push_dns_test
{
  local dnstools_tag="$1"

  docker build \
    --file "${THIS_SCRIPT_DIR}/docker_registry/dns_tools/dns_tools.dockerfile" \
    --tag "${dnstools_tag}" \
    "${THIS_SCRIPT_DIR}/docker_registry/dns_tools/context"

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

  kubectl run \
    --image "${dnstools_tag}" \
    --restart=Always \
    --namespace "default" \
    "${test_name}" \
    -- \
    sleep infinity
}

function build_and_push_dns
{
  local dns_tag="$1"

  bash "${THIS_SCRIPT_DIR}/docker_registry/dns/prepare_zone_file.bash"

  docker build \
    --file "${THIS_SCRIPT_DIR}/docker_registry/dns/dns.dockerfile" \
    --tag "${dns_tag}" \
    "${THIS_SCRIPT_DIR}/docker_registry/dns/context"

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
