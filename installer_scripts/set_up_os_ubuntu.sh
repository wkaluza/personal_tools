#!/usr/bin/env bash

set -euo pipefail

THIS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

source "${THIS_SCRIPT_DIR}/../shell_script_imports/logging.sh"
source "${THIS_SCRIPT_DIR}/../shell_script_imports/common.sh"

function install_basics() {
  print_trace

  sudo apt-get update >/dev/null
  sudo apt-get upgrade --with-new-pkgs -y >/dev/null
  DEBIAN_FRONTEND=noninteractive sudo \
    --preserve-env=DEBIAN_FRONTEND apt-get install -y \
    snapd \
    scdaemon \
    rng-tools \
    vlc \
    jq \
    dislocker \
    software-properties-common \
    make \
    vim \
    curl \
    wget >/dev/null
}

function configure_bash() {
  print_trace

  local config_preamble="# WK workstation setup"
  local bashrc_path="$HOME/.bashrc"

  if test -f "${bashrc_path}" &&
    grep --silent "^${config_preamble}$" "${bashrc_path}"; then
    log_info "bash already configured"
  else
    echo "${config_preamble}" >>"${bashrc_path}"
    cat "${THIS_SCRIPT_DIR}/bashrc_append.sh" >>"${bashrc_path}"
  fi
}

function main() {
  ensure_not_sudo

  install_basics

  configure_bash

  log_info "Success!"
  wait_and_reboot
}

# Entry point
main
