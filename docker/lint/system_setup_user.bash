set -euo pipefail

function main
{
  source "${IMPORTS_DIR}/files_user/user_import.bash"

  install_shfmt
}

# Entry point
main
