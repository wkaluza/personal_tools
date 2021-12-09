#!/usr/bin/env bash

set -euo pipefail

THIS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

source "${THIS_SCRIPT_DIR}/../shell_script_imports/logging.bash"
source "${THIS_SCRIPT_DIR}/../shell_script_imports/common.bash"

function install_docker {
  print_trace

  local url="https://download.docker.com/linux/ubuntu"
  local key="/usr/share/keyrings/docker-archive-keyring.gpg"

  sudo apt-get update >/dev/null
  DEBIAN_FRONTEND=noninteractive sudo \
    --preserve-env=DEBIAN_FRONTEND apt-get install -y \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release \
    curl >/dev/null

  curl -fsSL https://download.docker.com/linux/ubuntu/gpg |
    sudo gpg --dearmor -o "${key}"

  echo \
    "deb [arch=amd64 signed-by=${key}] ${url} $(lsb_release -cs) stable" |
    sudo tee /etc/apt/sources.list.d/docker.list >/dev/null

  sudo apt-get update >/dev/null
  DEBIAN_FRONTEND=noninteractive sudo \
    --preserve-env=DEBIAN_FRONTEND apt-get install -y \
    docker-ce \
    docker-ce-cli \
    containerd.io >/dev/null

  sudo systemctl enable docker.service
  sudo systemctl enable containerd.service

  # Create the docker group if it does not exist
  sudo getent group docker || sudo groupadd docker
  if [[ "${USER:-_user_not_defined_}" == "_user_not_defined_" ]]; then
    log_warning "Current user not defined"
  else
    sudo usermod -aG docker "$USER" >/dev/null
  fi
}

function install_docker_unless_already_installed {
  print_trace

  if docker --version >/dev/null 2>&1; then
    log_info "docker is already installed"
    docker run --rm hello-world >/dev/null
    docker info
  else
    log_info "Installing docker"
    install_docker
    log_info "Success! Reboot required."
    log_info "Next: configure credential provider"
  fi
}

function main {
  ensure_not_sudo
  install_docker_unless_already_installed

  echo Success
}

# Entry point
main
