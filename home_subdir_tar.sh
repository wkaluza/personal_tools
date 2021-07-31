#!/usr/bin/env bash

set -euo pipefail

function main() {
  local dir_name="$1"

  local current_date_time
  current_date_time="$(date --utc +'%Y%m%d%H%M%S')"

  tar -C "${HOME}" \
    --exclude "./${dir_name}/placeholder_no_such_dir/*" \
    -cvf "${HOME}/${dir_name}_${current_date_time}.tar" \
    "./${dir_name}/"
}

# Entry point
main "$1"
