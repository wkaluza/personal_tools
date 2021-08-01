#!/usr/bin/env bash

set -euo pipefail

THIS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

function main() {
  local jetbrains_toolbox_tar_gz="$1"

  local today_yymmdd
  today_yymmdd="$(date --utc +'%Y%m%d%H%M%S')"
  local image_name="set_up_ubuntu_${today_yymmdd}"

  docker build \
    -t "${image_name}" \
    -f "${THIS_SCRIPT_DIR}/test_ubuntu_setup.dockerfile" \
    "${THIS_SCRIPT_DIR}"

  docker run \
    --rm \
    --interactive \
    --tty \
    --volume "${THIS_SCRIPT_DIR}/..:/home/someuser/workspace" \
    "${image_name}" \
    "./installer_scripts/set_up_os_ubuntu.sh" \
    "${jetbrains_toolbox_tar_gz}"
}

# Entry point
main "$1"
