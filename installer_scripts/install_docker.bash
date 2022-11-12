set -euo pipefail
if command -v shopt &>/dev/null; then
  shopt -s inherit_errexit
fi
THIS_SCRIPT_DIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"
cd "${THIS_SCRIPT_DIR}"

source "${THIS_SCRIPT_DIR}/../shell_script_imports/preamble.bash"

function install_docker
{
  print_trace

  local url="https://download.docker.com/linux/ubuntu"
  local key="/usr/share/keyrings/docker-archive-keyring.gpg"

  sudo apt-get update >/dev/null
  sudo apt-get install --yes \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg >/dev/null

  curl -fsSL "https://download.docker.com/linux/ubuntu/gpg" |
    sudo gpg --dearmor -o "${key}"

  echo \
    "deb [arch=$(dpkg --print-architecture)" \
    "signed-by=${key}]" \
    "${url}" \
    "$(os_version_codename)" \
    "stable" |
    sudo tee /etc/apt/sources.list.d/docker.list >/dev/null

  sudo apt-get update >/dev/null
  sudo apt-get install --yes \
    docker-ce \
    docker-ce-cli \
    containerd.io >/dev/null

  sudo systemctl enable docker.service
  sudo systemctl enable containerd.service
}

function enable_sudoless_docker
{
  print_trace

  # Create the docker group if it does not exist
  getent group docker || sudo addgroup docker

  sudo adduser "$(id -un)" docker
}

function install_docker_unless_already_installed
{
  print_trace

  if docker --version >/dev/null 2>&1; then
    log_info "docker is already installed"
    docker run --rm hello-world >/dev/null
    docker info
  else
    log_info "Installing docker"

    install_docker
    enable_sudoless_docker
  fi
}

function main
{
  ensure_not_sudo
  install_docker_unless_already_installed

  log_info "Success: $(basename "$0")"
}

# Entry point
main
