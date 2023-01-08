set -euo pipefail
if command -v shopt &>/dev/null; then
  shopt -s inherit_errexit
fi

function main
{
  source "${IMPORTS_DIR}/files_user/user_import.bash"

  configure_go
  configure_node

  install_shfmt
  install_prettier
  install_yq
  install_kubectl
}

# Entry point
main
