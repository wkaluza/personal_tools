set -euo pipefail
if command -v shopt &>/dev/null; then
  shopt -s inherit_errexit
fi

function main
{
  source "${IMPORTS_DIR}/files_root/root_import.bash"

  install_jq
  install_git
  install_golang
  install_shellcheck
  install_python3
  install_nodejs
}

main
