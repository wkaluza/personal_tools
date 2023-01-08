set -euo pipefail
if command -v shopt &>/dev/null; then
  shopt -s inherit_errexit
fi
THIS_SCRIPT_DIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"
cd "${THIS_SCRIPT_DIR}"

source "${THIS_SCRIPT_DIR}/../../../shell_script_imports/preamble.bash"

GIT_FRONTEND_STACK_NAME="local_git_frontend_stack"

function append_A_record
{
  local domain="$1"
  local ip="$2"
  local zone_file="$3"

  echo "${domain}. IN A ${ip}" >>"${zone_file}"
}

function reset_zone_file
{
  local source_zone_file="$1"
  local final_zone_file="$2"

  rm -rf "${final_zone_file}"
  cp \
    "${source_zone_file}" \
    "${final_zone_file}"
}

function main
{
  local source_zone_file="${THIS_SCRIPT_DIR}/localhost.dns.base"
  local final_zone_file="${THIS_SCRIPT_DIR}/localhost___.dns"
  local startup_test_ip="123.132.213.231"
  local git_frontend_container_name
  git_frontend_container_name="$(docker network inspect minikube |
    jq --raw-output '.[0].Containers | to_entries[].value.Name' - |
    grep "${GIT_FRONTEND_STACK_NAME}" |
    grep "reverse_proxy")"

  local git_frontend_ip
  git_frontend_ip="$(docker network inspect minikube |
    jq ".[0].Containers | to_entries[]" - |
    jq ". | select(.value.Name == \"${git_frontend_container_name}\")" - |
    jq --raw-output ".value.IPv4Address" - |
    sed -E 's|([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+).*|\1|')"
  local webhook_sink_ip
  webhook_sink_ip="$(minikube ip)"

  reset_zone_file \
    "${source_zone_file}" \
    "${final_zone_file}"

  append_A_record \
    "${DOMAIN_EXTERNAL_STARTUP_TEST_dmzrfohk}" \
    "${startup_test_ip}" \
    "${final_zone_file}"

  append_A_record \
    "${DOMAIN_WEBHOOK_SINK_a8800f5b}" \
    "${webhook_sink_ip}" \
    "${final_zone_file}"

  append_A_record \
    "${DOMAIN_GIT_FRONTEND_df29c969}" \
    "${git_frontend_ip}" \
    "${final_zone_file}"

  log_info "Success $(basename "$0")"
}

main
