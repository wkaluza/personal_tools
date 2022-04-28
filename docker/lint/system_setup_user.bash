set -euo pipefail
shopt -s inherit_errexit

function main
{
  source "${IMPORTS_DIR}/files_user/user_import.bash"

  configure_go
  configure_node

  install_shfmt
  install_prettier
  install_pyyaml
}

# Entry point
main
