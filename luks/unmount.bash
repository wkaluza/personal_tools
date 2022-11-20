set -euo pipefail
if command -v shopt &>/dev/null; then
  shopt -s inherit_errexit
fi
THIS_SCRIPT_DIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"
cd "${THIS_SCRIPT_DIR}"

source "${THIS_SCRIPT_DIR}/../shell_script_imports/preamble.bash"

function main
{
  local device="$1"

  local mapping_name="pcspec_${device}_luks"

  local mount_point="${HOME}/luks/${mapping_name}"

  sudo umount "${mount_point}"
  sudo cryptsetup close "${mapping_name}"

  log_info "Success $(basename "$0")"
}

# Entry point
main "$1"
