#!/usr/bin/env bash

set -euo pipefail

THIS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

function main {
#  apt-get update
#  apt-get upgrade -y
#  DEBIAN_FRONTEND=noninteractive apt-get install -y \
#    curl \
#    git
#
#  apt-get autoremove -y
#  apt-get clean


  echo "========================================"

  echo "Script running as:"
  echo "User name: $(id -un)"
  echo "User ID: $(id -u)"
  echo "Group ID: $(id -g)"
  echo ""
  echo "HOME is ${HOME}"
  echo "WORKSPACE is ${WORKSPACE}"
  echo "pwd is $(pwd)"
  echo "THIS_SCRIPT_DIR is ${THIS_SCRIPT_DIR}"
  echo "IMPORTS_DIR is ${IMPORTS_DIR}"
  echo ""

  echo source "${IMPORTS_DIR}/files_common/common_import.sh"
  source "${IMPORTS_DIR}/files_common/common_import.sh"
  echo "Call common_import_fn..."
  common_import_fn

  echo source "${IMPORTS_DIR}/files_root/root_import.sh"
  source "${IMPORTS_DIR}/files_root/root_import.sh"
  echo "Call root_import_fn..."
  root_import_fn

  echo "========================================"
}

# Entry point
main
