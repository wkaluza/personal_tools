#!/usr/bin/env bash

set -euo pipefail

function main {
  for f in $(find . -type f -iname '*.bash'); do
    shfmt -i 2 -w "${f}"
  done

  for f in $(find . -type f -iname '*.json'); do
    cp "${f}" "${f}.temp"
    jq --sort-keys \
      '.' \
      "${f}" >"${f}.temp"
    mv "${f}.temp" "${f}"
  done
}

# Entry point
main
