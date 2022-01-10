#!/usr/bin/env bash

set -euo pipefail

function main
{
  local device="$1"

  local encrypted_device="/dev/${device}"
  local mapping_name="pcspec_${device}_luks"

  local mapped_device="/dev/mapper/${mapping_name}"
  local mount_point="${HOME}/luks/${mapping_name}"

  mkdir --parents "${mount_point}"

  sudo cryptsetup open "${encrypted_device}" "${mapping_name}"
  sleep 5
  sudo mount "${mapped_device}" "${mount_point}"
}

# Entry point
main "$1"
