#!/usr/bin/env bash

THIS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

source "${THIS_SCRIPT_DIR}/shell_script_imports/logging.sh"

function main() {
  local exited_containers
  exited_containers=$(docker container list --all --quiet --filter status=exited)
  if test -z "$exited_containers"; then
    log_info "No exited containers"
  else
    log_info "Deleting exited containers"
    docker container rm --volumes $exited_containers
  fi

  log_info "Pruning unused images"
  docker image prune --all --force
}

# Entry point
main
