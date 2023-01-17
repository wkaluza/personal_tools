set -euo pipefail
if command -v shopt &>/dev/null; then
  shopt -s inherit_errexit
fi
THIS_SCRIPT_DIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"
cd "${THIS_SCRIPT_DIR}"

source "${THIS_SCRIPT_DIR}/shell_script_imports/preamble.bash"

function ensure_host_is_in_etc_hosts_file
{
  local host="$1"
  local ip="$2"

  local hosts_file="/etc/hosts"

  if ! cat "${hosts_file}" |
    quiet grep "${host}"; then
    log_info "Need to add ${host} to ${hosts_file} ..."

    echo "${ip} ${host}" |
      quiet sudo tee --append "${hosts_file}"
  fi
}

function generate_cert
{
  local domain="$1"

  quiet mkcert \
    -cert-file "${domain}.pem" \
    -key-file "${domain}.secret" \
    "${domain}"
}

function list_local_domains
{
  cat "${THIS_SCRIPT_DIR}/shell_script_imports/local_domains.json" |
    jq '. | to_entries' - |
    jq '. | map( .value )' - |
    jq --raw-output '.[]' - |
    sort
}

function main
{
  local certs_dir="${HOME}/.wk_certificates___"

  quiet mkcert -install

  rm -rf "${certs_dir}"
  mkdir --parents "${certs_dir}"

  quiet pushd "${certs_dir}"

  for domain in $(list_local_domains); do
    quiet generate_cert "${domain}"
    quiet ensure_host_is_in_etc_hosts_file \
      "${domain}" \
      "127.0.0.1"
  done

  quiet popd

  log_info "Success $(basename "$0")"
}

main
