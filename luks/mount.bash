set -euo pipefail
shopt -s inherit_errexit

KEY_TYPE_NOT_DEFINED="___KEY_TYPE_NOT_DEFINED___"

function main
{
  local device="$1"
  local key_type="$2"

  local encrypted_device="/dev/${device}"
  local mapping_name="pcspec_${device}_luks"

  local mapped_device="/dev/mapper/${mapping_name}"
  local mount_point="${HOME}/luks/${mapping_name}"

  mkdir --parents "${mount_point}"

  if [[ "${key_type}" == "${KEY_TYPE_NOT_DEFINED}" ]]; then
    sudo cryptsetup open \
      "${encrypted_device}" \
      "${mapping_name}"
  else
    pass show "luks_passphrase_${key_type}" |
      tr -d '\n' |
      sudo cryptsetup open \
        --key-file - \
        "${encrypted_device}" \
        "${mapping_name}"
  fi

  sudo mount "${mapped_device}" "${mount_point}"

  echo "Success $(basename "$0")"
}

# Entry point
main "$1" "${2:-"${KEY_TYPE_NOT_DEFINED}"}"
