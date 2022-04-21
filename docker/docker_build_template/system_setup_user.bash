set -euo pipefail
shopt -s inherit_errexit

THIS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

function main
{
  echo "========================================"

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

  echo source "${IMPORTS_DIR}/files_user/user_import.bash"
  source "${IMPORTS_DIR}/files_user/user_import.bash"
  echo "Call user_import_fn..."
  user_import_fn

  echo "========================================"
}

# Entry point
main
