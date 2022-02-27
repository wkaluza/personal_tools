set -euo pipefail

THIS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

function main
{
  source "${IMPORTS_DIR}/files_root/root_import.bash"

  install_basics
  install_jq
  install_golang
}

# Entry point
main
