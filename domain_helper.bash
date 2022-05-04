set -euo pipefail
if command -v shopt &>/dev/null; then
  shopt -s inherit_errexit
fi
THIS_SCRIPT_DIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"
cd "${THIS_SCRIPT_DIR}"

source "${THIS_SCRIPT_DIR}/shell_script_imports/logging.bash"

function ensure_host_is_in_etc_hosts_file
{
  local host="$1"
  local ip="$2"

  local hosts_file="/etc/hosts"

  if ! cat "${hosts_file}" |
    grep "${host}" >/dev/null; then
    log_info "Need to add ${host} to ${hosts_file} ..."

    echo "${ip} ${host}" |
      sudo tee --append "${hosts_file}" >/dev/null
  fi
}

function generate_cert
{
  local domain="$1"

  mkcert \
    -cert-file "${domain}.pem" \
    -key-file "${domain}.secret" \
    "${domain}" >/dev/null 2>&1
}

function list_local_domains
{
  cat "${THIS_SCRIPT_DIR}/local_domains.json" |
    jq '. | to_entries' - |
    jq '. | map( .value )' - |
    jq --raw-output '.[]' - |
    sort
}

function main
{
  local certs_dir="${HOME}/.certificates___"

  mkcert -install >/dev/null 2>&1

  rm -rf "${certs_dir}"
  mkdir --parents "${certs_dir}"

  pushd "${certs_dir}" >/dev/null

  for domain in $(list_local_domains); do
    generate_cert "${domain}" >/dev/null 2>&1
    ensure_host_is_in_etc_hosts_file \
      "${domain}" \
      "127.0.0.1" >/dev/null 2>&1
  done

  popd >/dev/null

  log_info "Success: $(basename "$0")"
}

main
