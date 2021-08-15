#!/usr/bin/env bash

set -euo pipefail

function main() {
  echo "Setup script running as unprivileged user:"
  echo "USER ID: $(id -u)"
  echo "GROUP ID: $(id -g)"
  echo "USER NAME: $(id -un)"
}

# Entry point
main
