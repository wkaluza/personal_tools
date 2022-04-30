set -euo pipefail
shopt -s inherit_errexit

THIS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
cd "${THIS_SCRIPT_DIR}"

function main
{
  local dislocker_dir="$1"
  local mount_point="$2"

  sudo umount -d "${mount_point}"
  sleep 5
  sudo umount -d "${dislocker_dir}"
}

# Entry point
main "$1" "$2"
