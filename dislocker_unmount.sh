#!/usr/bin/env bash

set -euo pipefail

function main {
  local dislocker_dir="$1"
  local mount_point="$2"

  sudo umount -d "${mount_point}"
  sleep 5
  sudo umount -d "${dislocker_dir}"
}

# Entry point
main "$1" "$2"
