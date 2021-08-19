#!/usr/bin/env bash

set -euo pipefail

function main() {
  local encrypted_device="/dev/sda"
  local mapping_name="pcspec_sda_luks"

  local mapped_device="/dev/mapper/${mapping_name}"
  local mount_point="${HOME}/luks/${mapping_name}"

  mkdir --parents "${mount_point}"

  sudo cryptsetup open "${encrypted_device}" "${mapping_name}"
  sleep 5
  sudo mount "${mapped_device}" "${mount_point}"
}

# Entry point
main
