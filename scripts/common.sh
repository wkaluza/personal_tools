#!/usr/bin/env bash

set -euo pipefail

function run_in_context {
  local dir_path
  dir_path="$(realpath "$1")"
  local fn_arg="$2"

  mkdir --parents "${dir_path}"
  pushd "${dir_path}"
  $fn_arg "${@:3}"
  popd
}
