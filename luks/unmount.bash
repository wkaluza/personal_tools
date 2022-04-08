set -euo pipefail

function main
{
  local device="$1"

  local mapping_name="pcspec_${device}_luks"

  local mount_point="${HOME}/luks/${mapping_name}"

  sudo umount "${mount_point}"
  sleep 5
  sudo cryptsetup close "${mapping_name}"
}

# Entry point
main "$1"
