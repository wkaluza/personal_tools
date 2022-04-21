set -euo pipefail
shopt -s inherit_errexit

function main
{
  source "${IMPORTS_DIR}/files_root/root_import.bash"

  install_jq
  install_golang
  install_shellcheck
}

# Entry point
main
