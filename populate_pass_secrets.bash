set -euo pipefail
if command -v shopt &>/dev/null; then
  shopt -s inherit_errexit
fi
THIS_SCRIPT_DIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"
cd "${THIS_SCRIPT_DIR}"

source "${THIS_SCRIPT_DIR}/shell_script_imports/preamble.bash"

function main
{
  pass_generate_if_absent \
    "${PASS_SECRET_ID_GOGS_USER_PASSWORD_hezqdg53}"
  pass_generate_if_absent \
    "${PASS_SECRET_ID_GOGS_CONFIG_SECRET_KEY_nelzbcve}"
  pass_generate_if_absent \
    "${PASS_SECRET_ID_GOGS_WEBHOOK_SECRET_8q7aqxbl}"

  log_info "Success $(basename "$0")"
}

main
