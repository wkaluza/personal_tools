#!/usr/bin/env bash

set -euo pipefail

function main() {
#  apt-get update
#  apt-get upgrade -y
#  DEBIAN_FRONTEND=noninteractive apt-get install -y \
#    curl \
#    git
#
#  apt-get autoremove -y
#  apt-get clean

  echo "Setup script running as root:"
  echo "USER ID: $(id -u)"
  echo "GROUP ID: $(id -g)"
  echo "USER NAME: $(id -un)"
}

# Entry point
main
