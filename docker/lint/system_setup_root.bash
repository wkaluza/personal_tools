set -euo pipefail

function main
{
  source "${IMPORTS_DIR}/files_root/root_import.bash"

  install_basics
  install_jq
  install_golang
}

# Entry point
main
