set -euo pipefail
if command -v shopt &>/dev/null; then
  shopt -s inherit_errexit
fi
THIS_SCRIPT_DIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"
cd "${THIS_SCRIPT_DIR}"

source "${THIS_SCRIPT_DIR}/shell_script_imports/preamble.bash"

function main
{
  local repo_name="$1"

  local username="wkaluza"
  local token
  token="$(pass_show "local_gogs_token_${username}")"
  local auth_header="Authorization: token ${token}"

  gogs_delete_repo \
    "${DOMAIN_GIT_FRONTEND_df29c969}" \
    "${username}" \
    "${repo_name}" \
    "${auth_header}"

  echo "Success $(basename "$0")"
}

# Entry point
main "$1"
