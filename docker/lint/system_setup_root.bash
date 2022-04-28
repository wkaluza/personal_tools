set -euo pipefail
shopt -s inherit_errexit

function main
{
  source "${IMPORTS_DIR}/files_root/root_import.bash"

  install_jq
  install_golang
  install_shellcheck
  install_python3
  install_nodejs
}

# Entry point
main
