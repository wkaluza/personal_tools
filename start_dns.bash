set -euo pipefail
if command -v shopt &>/dev/null; then
  shopt -s inherit_errexit
fi
THIS_SCRIPT_DIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"
cd "${THIS_SCRIPT_DIR}"

source "${THIS_SCRIPT_DIR}/shell_script_imports/preamble.bash"

LOCAL_SERVICES_ROOT_DIR="${THIS_SCRIPT_DIR}/docker/swarm"
HOST_TIMEZONE="$(current_timezone)"
DNS_STACK_NAME="local_dns_stack"
LOCAL_SWARM_NODE_ID="$(get_local_node_id)"
DNS_IP_48zyazy8="192.168.49.200"

DNS_IMAGE_REFERENCE="${DOMAIN_DOCKER_REGISTRY_PRIVATE_a8a1ce1e}/dns:1"

function generate_dns_env
{
  local dns_config_corefile="${LOCAL_SERVICES_ROOT_DIR}/dns/corefile"
  local dns_config_corefile_digest
  dns_config_corefile_digest="$(cat "${dns_config_corefile}" |
    sha256 |
    take_first 8)"

  local dns_config_localhost_zone_file="${LOCAL_SERVICES_ROOT_DIR}/dns/localhost___.dns"
  local dns_config_localhost_zone_file_digest
  dns_config_localhost_zone_file_digest="$(cat "${dns_config_localhost_zone_file}" |
    sha256 |
    take_first 8)"

  cat <<EOF
DNS_CONFIG_COREFILE='${dns_config_corefile}'
DNS_CONFIG_COREFILE_DIGEST='${dns_config_corefile_digest}'
DNS_CONFIG_LOCALHOST_ZONE_FILE='${dns_config_localhost_zone_file}'
DNS_CONFIG_LOCALHOST_ZONE_FILE_DIGEST='${dns_config_localhost_zone_file_digest}'
DNS_CONTEXT='${LOCAL_SERVICES_ROOT_DIR}/dns/context'
DNS_DOCKERFILE='${LOCAL_SERVICES_ROOT_DIR}/dns/dns.dockerfile'
DNS_IMAGE_REFERENCE='${DNS_IMAGE_REFERENCE}'
DNS_IP_48zyazy8='${DNS_IP_48zyazy8}'
HOST_TIMEZONE='${HOST_TIMEZONE}'
LOCAL_NODE_ID='${LOCAL_SWARM_NODE_ID}'
EOF
}

function start_dns
{
  bash "${LOCAL_SERVICES_ROOT_DIR}/dns/prepare_build_context.bash"

  build_docker_stack \
    generate_dns_env \
    "${THIS_SCRIPT_DIR}/local_dns.json" \
    "${DNS_STACK_NAME}"

  start_docker_stack \
    generate_dns_env \
    "${THIS_SCRIPT_DIR}/local_dns.json" \
    "${DNS_STACK_NAME}"

  push_docker_stack \
    generate_dns_env \
    "${THIS_SCRIPT_DIR}/local_dns.json" \
    "${DNS_STACK_NAME}"

  connect_stack_containers_to_network \
    "minikube" \
    "${DNS_IP_48zyazy8}" \
    "wk.connect.cluster-cnr8lm0i" \
    "true" \
    "${DNS_STACK_NAME}"
}

function main
{
  start_dns

  log_info "Success $(basename "$0")"
}

main
