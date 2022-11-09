set -euo pipefail
if command -v shopt &>/dev/null; then
  shopt -s inherit_errexit
fi
THIS_SCRIPT_DIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"
cd "${THIS_SCRIPT_DIR}"

DOCKER_IMAGE_TAG="test_ubuntu_bare_minimum:latest"

function on_exit
{
  docker image rm \
    --force \
    --no-prune \
    "${DOCKER_IMAGE_TAG}"
}

trap on_exit EXIT

source "${THIS_SCRIPT_DIR}/../shell_script_imports/preamble.bash"

function main
{
  local docker_socket="/var/run/docker.sock"

  gpgconf --kill gpg-agent scdaemon

  docker build \
    --build-arg "DOCKER_UID=$(id -u)" \
    --build-arg "DOCKER_GID=$(id -g)" \
    --build-arg "DOCKER_USERNAME=$(id -un)" \
    --build-arg "TIMEZONE=$(readlink -e /etc/localtime)" \
    --build-arg "DOCKER_SYSTEM_GID=$(getent group docker | awk -F: '{print $3}')" \
    --file "${THIS_SCRIPT_DIR}/test_ubuntu_bare_minimum.dockerfile" \
    --tag "${DOCKER_IMAGE_TAG}" \
    "${THIS_SCRIPT_DIR}"

  docker run \
    --interactive \
    --privileged \
    --rm \
    --tty \
    --volume "${docker_socket}:${docker_socket}" \
    --volume "/dev/bus/usb:/dev/bus/usb" \
    "${DOCKER_IMAGE_TAG}" \
    bash \
    "/home/$(id -un)/workspace/ubuntu_bare_minimum.bash" \
    "/home/$(id -un)/workspace/jetbrains-toolbox___.tar.gz"

  log_info "Success: $(basename "$0")"
}

main
