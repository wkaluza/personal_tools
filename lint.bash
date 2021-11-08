#!/usr/bin/env bash

set -euo pipefail

function main {
  find . -type f -iname '*.bash' |
    xargs --no-run-if-empty --max-lines=1 shfmt -i 2 -w
}

# Entry point
main
