set -euo pipefail
shopt -s inherit_errexit

function main
{
  local device="$1"

  local encrypted_device="/dev/${device}"
  local mapping_name="pcspec_${device}_luks"

  local mapped_device="/dev/mapper/${mapping_name}"
  local mount_point="${HOME}/luks/${mapping_name}"

  sudo cryptsetup -y -v luksFormat "${encrypted_device}"
  sudo cryptsetup open "${encrypted_device}" "${mapping_name}"
  sudo mkfs.ext4 "${mapped_device}"
  mkdir --parents "${mount_point}"

  sudo mount "${mapped_device}" "${mount_point}"
  sleep 5
  sudo chown --recursive "$(id -u):$(id -g)" "${mount_point}"
  sudo umount "${mount_point}"
  sleep 5
  sudo cryptsetup close "${mapping_name}"
}

# Entry point
main "$1"
