set -euo pipefail
if command -v shopt &>/dev/null; then
  shopt -s inherit_errexit
fi
THIS_SCRIPT_DIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"
cd "${THIS_SCRIPT_DIR}"

source "${THIS_SCRIPT_DIR}/../../shell_script_imports/common.bash"
source "${THIS_SCRIPT_DIR}/../../shell_script_imports/logging.bash"
source "${THIS_SCRIPT_DIR}/../../shell_script_imports/git_helpers.bash"
source "${THIS_SCRIPT_DIR}/../../shell_script_imports/gogs_helpers.bash"

source <(cat "${THIS_SCRIPT_DIR}/../../local_domains.json" |
  jq '. | to_entries' - |
  jq '. | map( "\(.key)=\"\(.value)\"" )' - |
  jq --raw-output '. | .[]' - |
  sort)

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
