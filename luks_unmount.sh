#!/usr/bin/env bash

set -euo pipefail

function main() {
  local encrypted_device="/dev/sda"
  local mapping_name="pcspec_sda_luks"

  local mapped_device="/dev/mapper/${mapping_name}"
  local mount_point="${HOME}/luks/${mapping_name}"

  sudo umount "${mount_point}"
  sleep 5
  sudo cryptsetup close "${mapping_name}"
}

# Entry point
main
