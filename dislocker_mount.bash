#!/usr/bin/env bash

set -euo pipefail

function main {
  local encrypted_partition="$1"
  local dislocker_dir="$2"
  local mount_point="$3"

  sudo mkdir -p "${dislocker_dir}"
  sudo mkdir -p "${mount_point}"

  sudo dislocker "${encrypted_partition}" -u -- "${dislocker_dir}"
  sleep 5
  sudo mount -o loop "${dislocker_dir}/dislocker-file" "${mount_point}"
}

# Entry point
main "$1" "$2" "$3"