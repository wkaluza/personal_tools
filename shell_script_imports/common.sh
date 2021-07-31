#!/usr/bin/env bash

set -euo pipefail

function ensure_not_sudo() {
  if test "0" -eq "$(id -u)"; then
    echo "Do not run this as root"
    exit 1
  fi
}

function press_any_key_to_() {
  local action="$1"

  echo "Press any key to ${action} or Ctrl-c to quit"
  read -n 1 -s -r
}

function wait_and_reboot() {
  press_any_key_to_ "reboot"
  sudo reboot
}
