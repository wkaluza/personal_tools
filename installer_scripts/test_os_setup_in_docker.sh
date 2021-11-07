#!/usr/bin/env bash

set -euo pipefail

THIS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

function main {
  local repo_root
  repo_root="$(realpath "${THIS_SCRIPT_DIR}/../")"
  local docker_dir="${repo_root}/docker"

  "${docker_dir}"/run_in_docker.sh \
    "${repo_root}" \
    "${docker_dir}/docker_jobs.json" \
    "test_os_setup"
}

# Entry point
main
