set -euo pipefail

THIS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

function main
{
  source "${IMPORTS_DIR}/files_user/user_import.bash"

  install_shfmt
}

# Entry point
main
