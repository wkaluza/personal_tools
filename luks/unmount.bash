set -euo pipefail
shopt -s inherit_errexit

THIS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
cd "${THIS_SCRIPT_DIR}"

function main
{
  local device="$1"

  local mapping_name="pcspec_${device}_luks"

  local mount_point="${HOME}/luks/${mapping_name}"

  sudo umount "${mount_point}"
  sudo cryptsetup close "${mapping_name}"
}

# Entry point
main "$1"
