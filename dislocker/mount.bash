set -euo pipefail
if command -v shopt &>/dev/null; then
  shopt -s inherit_errexit
fi
THIS_SCRIPT_DIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"
cd "${THIS_SCRIPT_DIR}"

function main
{
  local encrypted_partition="$1"
  local dislocker_dir="$2"
  local mount_point="$3"

  sudo mkdir --parents "${dislocker_dir}"
  sudo mkdir --parents "${mount_point}"

  sudo dislocker "${encrypted_partition}" -u -- "${dislocker_dir}"
  sleep 5
  sudo mount -o loop "${dislocker_dir}/dislocker-file" "${mount_point}"
}

main "$1" "$2" "$3"
