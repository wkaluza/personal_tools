#!/usr/bin/env bash

set -euo pipefail

THIS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

function main
{
  for f in $(find "${THIS_SCRIPT_DIR}" -type f -iname '*.bash'); do
    shfmt -i 2 -fn -w "${f}"
  done

  for f in $(find "${THIS_SCRIPT_DIR}" -type f -iname '*.json'); do
    cp "${f}" "${f}.temp"
    jq --sort-keys \
      '.' \
      "${f}.temp" >"${f}"
    rm "${f}.temp"
  done
}

# Entry point
main
