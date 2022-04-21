set -euo pipefail
shopt -s inherit_errexit

function main
{
  source "${IMPORTS_DIR}/files_user/user_import.bash"

  configure_go

  install_shfmt
}

# Entry point
main
