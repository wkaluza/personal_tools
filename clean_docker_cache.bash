THIS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

source "${THIS_SCRIPT_DIR}/shell_script_imports/logging.bash"

function main
{
  local running_containers
  running_containers=$(docker container list --all --quiet --filter="status=running")
  if test -z "$running_containers"; then
    log_info "No running containers"
  else
    log_info "Stopping running containers"
    docker stop $running_containers
  fi

  local exited_containers
  exited_containers=$(docker container list --all --quiet --filter="status=exited")
  if test -z "$exited_containers"; then
    log_info "No exited containers"
  else
    log_info "Deleting exited containers"
    docker rm $exited_containers
  fi

  log_info "Pruning unused images"
  docker image prune --force
}

# Entry point
main
