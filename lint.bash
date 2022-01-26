#!/usr/bin/env bash

set -euo pipefail

THIS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

function main
{
  for f in $(find "${THIS_SCRIPT_DIR}" -type f -iname '*.bash'); do
    echo "${f}"
    shfmt -i 2 -fn -w "${f}" &
  done

  for f in $(find "${THIS_SCRIPT_DIR}" -type f -iname '*.json'); do
    echo "${f}"

    local json_text
    json_text="$(cat "${f}")"

    echo "${json_text}" |
      jq --sort-keys \
        '.' \
        - >"${f}" &
  done

  echo "Waiting..."
  wait

  echo "Success"
}

# Entry point
main
