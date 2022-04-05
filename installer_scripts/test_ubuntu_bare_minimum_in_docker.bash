set -euo pipefail

THIS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
DOCKER_IMAGE_TAG="test_ubuntu_bare_minimum:latest"

function on_exit
{
  docker image rm \
    --force \
    --no-prune \
    "${DOCKER_IMAGE_TAG}"
}

trap on_exit EXIT

source "${THIS_SCRIPT_DIR}/../shell_script_imports/logging.bash"

function main
{
  local docker_socket="/var/run/docker.sock"

  docker build \
    --build-arg "USER_ID=$(id -u)" \
    --build-arg "GROUP_ID=$(id -g)" \
    --build-arg "USERNAME=$(id -un)" \
    --build-arg "TIMEZONE=$(readlink -e /etc/localtime)" \
    --build-arg "WORKSPACE=$(pwd)" \
    --build-arg "DOCKER_GROUP_ID=$(getent group docker | awk -F: '{print $3}')" \
    --file "${THIS_SCRIPT_DIR}/test_ubuntu_bare_minimum.dockerfile" \
    --tag "${DOCKER_IMAGE_TAG}" \
    "${THIS_SCRIPT_DIR}"

  docker run \
    --interactive \
    --rm \
    --tty \
    --volume "${docker_socket}:${docker_socket}" \
    "${DOCKER_IMAGE_TAG}" \
    bash "/home/$(id -un)/workspace/ubuntu_bare_minimum.bash"

  log_info "Success: $(basename $0)"
}

main