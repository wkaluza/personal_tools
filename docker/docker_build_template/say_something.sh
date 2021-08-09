#!/usr/bin/env bash

set -euo pipefail

function main() {
  local first="$1"
  local second="$2"

  echo "${first} ${second}"
}

# Entry point
main "$1" "$2"
