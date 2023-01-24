set -euo pipefail
if command -v shopt &>/dev/null; then
  shopt -s inherit_errexit
fi
THIS_SCRIPT_DIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"

source "${THIS_SCRIPT_DIR}/shell_script_imports/preamble.bash"

function main
{
  if mkcert -CAROOT &>/dev/null &&
    test -f "$(mkcert -CAROOT)/rootCA.pem"; then
    log_info "Certificates already exist"
  else
    log_info "Generating certificates..."
    bash "${THIS_SCRIPT_DIR}/domain_helper.bash"
  fi

  log_info "Success $(basename "$0")"
}

main
