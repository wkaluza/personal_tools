set -euo pipefail
if command -v shopt &>/dev/null; then
  shopt -s inherit_errexit
fi
THIS_SCRIPT_DIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"
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
