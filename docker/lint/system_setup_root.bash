set -euo pipefail
shopt -s inherit_errexit

function main
{
  source "${IMPORTS_DIR}/files_root/root_import.bash"

  install_basics
  install_jq
  install_golang
}

# Entry point
main
