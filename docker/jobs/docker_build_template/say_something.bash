set -euo pipefail
if command -v shopt &>/dev/null; then
  shopt -s inherit_errexit
fi
THIS_SCRIPT_DIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"

function main
{
  local first="$1"
  local second="$2"
  local third="$3"
  local fourth="$4"

  echo "========================================"

  echo "${first} ${second}" "${third}" "${fourth}"
  echo ""
  echo "Script running as:"
  echo "User name: $(id -un)"
  echo "User ID: $(id -u)"
  echo "Group ID: $(id -g)"
  echo ""
  echo "HOME is ${HOME}"
  echo "DOCKER_PROFILE is ${DOCKER_PROFILE}"
  echo "WORKSPACE is ${WORKSPACE}"
  echo "pwd is $(pwd)"
  echo "THIS_SCRIPT_DIR is ${THIS_SCRIPT_DIR}"
  echo "IMPORTS_DIR is ${IMPORTS_DIR}"
  echo ""

  echo source "${IMPORTS_DIR}/files_common/common_import.bash"
  source "${IMPORTS_DIR}/files_common/common_import.bash"
  echo "Call common_import_fn..."
  common_import_fn

  echo source "${IMPORTS_DIR}/files_root/root_import.bash"
  source "${IMPORTS_DIR}/files_root/root_import.bash"
  echo "Call root_import_fn..."
  root_import_fn

  echo source "${IMPORTS_DIR}/files_user/user_import.bash"
  source "${IMPORTS_DIR}/files_user/user_import.bash"
  echo "Call user_import_fn..."
  user_import_fn

  echo "========================================"
}

# Entry point
main "$1" "$2" "$3" "$4"
