set -euo pipefail
if command -v shopt &>/dev/null; then
  shopt -s inherit_errexit
fi
THIS_SCRIPT_DIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"

source "${THIS_SCRIPT_DIR}/../../../../shell_script_imports/preamble.bash"

function main
{
  local ca_dir="${THIS_SCRIPT_DIR}/context/ca___"

  rm -rf "${ca_dir}"
  mkdir --parents "${ca_dir}"

  cp \
    "$(mkcert -CAROOT)/rootCA.pem" \
    "${ca_dir}/mkcert.crt"

  log_info "Success $(basename "$0")"
}

main
