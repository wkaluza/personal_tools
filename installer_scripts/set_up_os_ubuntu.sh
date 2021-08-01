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
    gnupg \
    jq \
    inkscape \
    libcanberra-gtk-module \
    libcanberra-gtk3-module \
    dislocker \
    software-properties-common \
    vim \
    curl \
    wget >/dev/null
}

function install_git() {
  print_trace

  sudo add-apt-repository -y ppa:git-core/ppa >/dev/null
  sudo apt-get update >/dev/null

  sudo apt-get install -y git >/dev/null
}

function install_github_cli() {
  print_trace

  local key="/usr/share/keyrings/githubcli-archive-keyring.gpg"
  local url="https://cli.github.com/packages"

  curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg |
    sudo gpg --dearmor -o "${key}"
  echo "deb [arch=amd64 signed-by=${key}] ${url} stable main" |
    sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null

  sudo apt-get update >/dev/null
  sudo apt-get install -y gh >/dev/null
}

function install_python() {
  print_trace

  sudo apt-get install -y \
    python3-dev \
    python3-pip \
    python3-venv >/dev/null

  python3 -u -m pip install --upgrade pip >/dev/null
  python3 -u -m pip install --upgrade certifi setuptools wheel >/dev/null
  python3 -u -m pip install --upgrade \
    pipenv >/dev/null
}

function install_cpp_toolchains() {
  print_trace

  sudo apt-get install -y \
    make \
    ninja-build \
    gcc-10 \
    g++-10 \
    clang-12 \
    clang-tools-12 \
    clang-format-12 \
    clang-tidy-12 >/dev/null
}

function install_cmake() {
  print_trace

  sudo apt-get install -y \
    apt-transport-https \
    ca-certificates \
    gnupg \
    software-properties-common \
    wget >/dev/null

  local url="https://apt.kitware.com/keys/kitware-archive-latest.asc"

  curl -fsSL "${url}" 2>/dev/null |
    sudo APT_KEY_DONT_WARN_ON_DANGEROUS_USAGE="DontWarn" \
      apt-key add - >/dev/null

  # Get Kitware Apt Archive Automatic Signing Key (2021) <debian@kitware.com>"
  sudo apt-key adv \
    --keyserver keyserver.ubuntu.com \
    --recv-keys 2EEA802239DDF0E52942A7B4FCEE74BB7F3C88C8

  sudo add-apt-repository \
    "deb https://apt.kitware.com/ubuntu/ $(lsb_release -cs) main" >/dev/null
  sudo apt-get update >/dev/null

  sudo apt-get install -y cmake >/dev/null
}

function install_jetbrains_toolbox() {
  print_trace

  local tar_gz_path="$1"

  local extract_target_name
  extract_target_name="$(basename "${tar_gz_path}" ".tar.gz")"
  local install_destination="/opt/jetbrains/jetbrains-toolbox"

  if ! test -x "${install_destination}"; then
    sudo mkdir -p "$(dirname "${install_destination}")"

    pushd "$(dirname "${tar_gz_path}")" >/dev/null
    tar -xzf "${tar_gz_path}"
    sudo cp \
      "./${extract_target_name}/$(basename "${install_destination}")" \
      "${install_destination}"

    sudo rm -rf "${tar_gz_path}"
    sudo rm -rf "./${extract_target_name}"
    popd >/dev/null
  else
    log_info "jetbrains-toolbox already installed at ${install_destination}"
  fi

  if ! test -x "${install_destination}"; then
    log_error "Something went wrong when installing jetbrains-toolbox"
    exit 1
  fi
}

function install_yubico_utilities() {
  print_trace

  sudo add-apt-repository -y ppa:yubico/stable >/dev/null
  sudo apt-get update >/dev/null
  sudo apt-get install -y \
    yubikey-manager \
    yubioath-desktop \
    yubikey-personalization-gui >/dev/null
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

function configure_git() {
  print_trace

  local pgp_signing_key_fingerprint="$1"

  git config --global user.email "wkaluza@protonmail.com"
  git config --global user.name "Wojciech Kaluza"

  git config --global init.defaultBranch main

  git config --global rebase.autosquash true
  git config --global pull.ff only
  git config --global merge.ff false

  git config --global log.showSignature true

  git config --global user.signingKey "${pgp_signing_key_fingerprint}"
  git config --global gpg.program gpg

  git config --global commit.gpgSign true
  git config --global merge.verifySignatures true

  git config --global rerere.enabled true
}

function configure_gpg() {
  print_trace

  local pgp_primary_key_fingerprint="$1"

  local gpg_home="$HOME/.gnupg"
  local gpg_config_dir="gpg_config"

  mkdir -p "$gpg_home"
  cp "${THIS_SCRIPT_DIR}/${gpg_config_dir}/gpg.conf" "${gpg_home}"
  cp "${THIS_SCRIPT_DIR}/${gpg_config_dir}/gpg-agent.conf" "${gpg_home}"
  chmod u+rwx,go-rwx "${gpg_home}"

  gpg --receive-keys "${pgp_primary_key_fingerprint}"
  # Set trust to ultimate
  echo "${pgp_primary_key_fingerprint}:6:" | gpg --import-ownertrust

  # Import GitHub's public key
  gpg --fetch-keys "https://github.com/web-flow.gpg"
}

function main() {
  local jetbrains_toolbox_tar_gz
  jetbrains_toolbox_tar_gz="$(realpath "$1")"

  if ! test -f "${jetbrains_toolbox_tar_gz}"; then
    log_error "Invalid path to jetbrains-toolbox archive"
    exit 1
  fi

  local pgp_primary_key_fingerprint="174C9368811039C87F0C806A896572D1E78ED6A7"
  local pgp_signing_key_fingerprint="143EE89AAC97053810D13E378A7E8CA85A62CF20"

  ensure_not_sudo

  install_basics
  install_git
  install_github_cli
  install_python
  install_cpp_toolchains
  install_cmake
  install_jetbrains_toolbox "${jetbrains_toolbox_tar_gz}"
  install_yubico_utilities

  configure_bash
  configure_gpg "${pgp_primary_key_fingerprint}"
  configure_git "${pgp_signing_key_fingerprint}"

  log_info "Success!"
  wait_and_reboot
}

# Entry point
main "$1"