#!/usr/bin/env bash

set -euo pipefail

function main {
  local device="$1"

  local encrypted_device="/dev/${device}"
  local mapping_name="pcspec_${device}_luks"

  local mapped_device="/dev/mapper/${mapping_name}"
  local mount_point="${HOME}/luks/${mapping_name}"

  sudo umount "${mount_point}"
  sleep 5
  sudo cryptsetup close "${mapping_name}"
}

# Entry point
main "$1"
