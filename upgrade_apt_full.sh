#!/usr/bin/env bash

set -euo pipefail

function main() {
  sudo apt-get update
  sudo apt-get upgrade --with-new-pkgs -y
  sudo apt-get dist-upgrade -y
  sudo apt-get autoremove -y
  sudo apt-get clean

  test -f /var/run/reboot-required &&
    echo reboot required ||
    echo reboot not required
}

# Entry point
main