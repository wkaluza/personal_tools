set -euo pipefail
if command -v shopt &>/dev/null; then
  shopt -s inherit_errexit
fi
THIS_SCRIPT_DIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"
cd "${THIS_SCRIPT_DIR}"

source "${THIS_SCRIPT_DIR}/../shell_script_imports/preamble.bash"

function main
{
  local dislocker_dir="$1"
  local mount_point="$2"

  sudo umount -d "${mount_point}"
  sleep 5
  sudo umount -d "${dislocker_dir}"

  log_info "Success $(basename "$0")"
}

# Entry point
main "$1" "$2"
