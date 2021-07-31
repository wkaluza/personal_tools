#!/usr/bin/env bash

set -euo pipefail

THIS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

source "${THIS_SCRIPT_DIR}/../shell_script_imports/logging.sh"
source "${THIS_SCRIPT_DIR}/../shell_script_imports/common.sh"

function install_docker() {
  if ! docker --version >/dev/null; then
    log_info "Installing docker"

    local url="https://download.docker.com/linux/ubuntu"
    local key="/usr/share/keyrings/docker-archive-keyring.gpg"

    sudo apt-get update >/dev/null
    sudo apt-get install -y \
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
    sudo apt-get install -y \
      docker-ce \
      docker-ce-cli \
      containerd.io >/dev/null

    sudo systemctl enable docker.service
    sudo systemctl enable containerd.service

    # Create the docker group if it does not exist
    sudo getent group docker || sudo groupadd docker
    sudo usermod -aG docker "$USER" >/dev/null
  else
    log_info "docker is already installed"
    docker run --rm hello-world >/dev/null
    docker info
  fi
}

function main() {
  ensure_not_sudo
  install_docker
  wait_and_reboot
}

# Entry point
main
