#!/usr/bin/env bash

set -euo pipefail

function main
{
  for f in $(find . -type f -iname '*.bash'); do
    shfmt -i 2 -fn -w "${f}"
  done

  for f in $(find . -type f -iname '*.json'); do
    cp "${f}" "${f}.temp"
    jq --sort-keys \
      '.' \
      "${f}.temp" >"${f}"
    rm "${f}.temp"
  done
}

# Entry point
main
