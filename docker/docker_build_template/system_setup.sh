#!/usr/bin/env bash

set -euo pipefail

function main() {
  apt-get update
  apt-get upgrade -y
  DEBIAN_FRONTEND=noninteractive apt-get install -y \
    curl \
    git
}

# Entry point
main
