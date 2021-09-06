#!/usr/bin/env bash

set -euo pipefail

THIS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

source "${THIS_SCRIPT_DIR}/../shell_script_imports/logging.sh"
source "${THIS_SCRIPT_DIR}/../shell_script_imports/common.sh"

function install_basics() {
  print_trace

  sudo apt-get update
  sudo apt-get upgrade --with-new-pkgs -y
  DEBIAN_FRONTEND=noninteractive sudo \
    --preserve-env=DEBIAN_FRONTEND apt-get install -y \
    snapd \
    scdaemon \
    rng-tools \
    gettext-base \
    vlc \
    meld \
    rdfind \
    gnupg \
    jq \
    mercurial \
    darcs \
    fossil \
    subversion \
    inkscape \
    libcanberra-gtk-module \
    libcanberra-gtk3-module \
    dislocker \
    software-properties-common \
    vim \
    curl \
    wget
}

function install_git() {
  print_trace

  sudo add-apt-repository -y ppa:git-core/ppa
  sudo apt-get update

  sudo apt-get install -y git
}

function install_github_cli() {
  print_trace

  local key="/usr/share/keyrings/githubcli-archive-keyring.gpg"
  local url="https://cli.github.com/packages"

  curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg |
    sudo gpg --dearmor -o "${key}"
  echo "deb [arch=amd64 signed-by=${key}] ${url} stable main" |
    sudo tee /etc/apt/sources.list.d/github-cli.list

  sudo apt-get update
  sudo apt-get install -y gh
}

function install_rust() {
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
  source $HOME/.cargo/env
  rustup update
}

function install_python() {
  print_trace

  local poetry_url="https://raw.githubusercontent.com/python-poetry/poetry/master/install-poetry.py"
  local poetry_bash_completion="/etc/bash_completion.d/poetry.bash-completion"

  sudo apt-get install -y \
    python3-dev \
    python3-pip \
    python3-venv

  python3 -u -m pip install --upgrade pip
  python3 -u -m pip install --upgrade certifi setuptools wheel
  python3 -u -m pip install --upgrade \
    pipenv

  curl -sSL "${poetry_url}" | python3 -
  "$HOME"/.local/bin/poetry completions bash |
    sudo tee "${poetry_bash_completion}"
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
    clang-tidy-12
}

function install_cmake() {
  print_trace

  sudo apt-get install -y \
    apt-transport-https \
    ca-certificates \
    gnupg \
    software-properties-common \
    wget

  local url="https://apt.kitware.com/keys/kitware-archive-latest.asc"

  curl -fsSL "${url}" 2>/dev/null |
    sudo APT_KEY_DONT_WARN_ON_DANGEROUS_USAGE="DontWarn" \
      apt-key add -

  # Get Kitware Apt Archive Automatic Signing Key (2021) <debian@kitware.com>"
  sudo apt-key adv \
    --keyserver keyserver.ubuntu.com \
    --recv-keys 2EEA802239DDF0E52942A7B4FCEE74BB7F3C88C8

  sudo add-apt-repository \
    "deb https://apt.kitware.com/ubuntu/ $(lsb_release -cs) main"
  sudo apt-get update

  sudo apt-get install -y cmake
}

function install_jetbrains_toolbox() {
  print_trace

  local tar_gz_path="$1"

  local install_destination="/opt/jetbrains/jetbrains-toolbox"

  if ! test -x "${install_destination}"; then
    sudo mkdir -p "$(dirname "${install_destination}")"

    pushd "$(dirname "${tar_gz_path}")"
    tar -xzf "${tar_gz_path}"

    local extracted_dir
    extracted_dir="$(find . -type d -name 'jetbrains-toolbox-*')"

    sudo cp \
      "${extracted_dir}/$(basename "${install_destination}")" \
      "${install_destination}"

    sudo rm -rf "${tar_gz_path}"
    sudo rm -rf "${extracted_dir}"
    popd
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

  sudo add-apt-repository -y ppa:yubico/stable
  sudo apt-get update
  sudo apt-get install -y \
    yubikey-manager \
    yubioath-desktop \
    yubikey-personalization-gui
}

function install_golang() {
  print_trace

  local go_archive="go.tar.gz"
  local v="1.16.6"
  local download_url="https://dl.google.com/go/go${v}.linux-amd64.tar.gz"
  # Must match PATH update in bashrc_append.sh
  local target_dir="/usr/local"

  if ! test -d "${target_dir}/go"; then
    curl -fsSL --output "./${go_archive}" "${download_url}"
    sudo mv "./${go_archive}" "${target_dir}"

    pushd "${target_dir}"
    sudo tar -xzf "./${go_archive}"
    sudo rm "./${go_archive}"
    popd
  else
    echo "golang is already installed"
    go version
  fi
}

function install_pijul() {
  local pijul_version="~1.0.0-alpha"

  sudo apt-get -y install \
    make \
    libsodium-dev \
    libclang-dev \
    pkg-config \
    libssl-dev \
    libxxhash-dev \
    libzstd-dev \
    clang

  cargo search pijul
  cargo install pijul --version "${pijul_version}"
}

function install_nodejs() {
  print_trace

  curl -sL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
  sudo apt-get install -y nodejs

  npm config set ignore-scripts true
}

function install_tex_live() {
  print_trace

  sudo apt-get install -y \
    texlive-full
}

function install_chrome() {
  print_trace

  local url="https://dl.google.com/linux/direct"

  sudo apt-get install -y \
    fonts-liberation

  if test -x "/opt/google/chrome/google-chrome"; then
    log_info "Google Chrome already installed"
  else
    wget --output-document ./chrome.deb \
      "${url}/google-chrome-stable_current_amd64.deb"
    sudo dpkg --install ./chrome.deb
    rm ./chrome.deb
  fi

  google-chrome --version
}

function install_brave() {
  local key="/usr/share/keyrings/brave-browser-archive-keyring.gpg"
  local url="https://brave-browser-apt-release.s3.brave.com"

  sudo apt-get install apt-transport-https curl
  sudo curl -fsSL -o "${key}" "${url}/brave-browser-archive-keyring.gpg"
  echo "deb [arch=amd64 signed-by=${key}] ${url} stable main" |
    sudo tee /etc/apt/sources.list.d/brave-browser-release.list

  sudo apt-get update
  sudo apt-get install -y brave-browser

  brave-browser --version
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

  git config --global url."git@github.com:".insteadOf "https://github.com/"
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
    log_error "Invalid path to jetbrains-toolbox archive: ${jetbrains_toolbox_tar_gz}"
    exit 1
  fi

  local pgp_primary_key_fingerprint="174C9368811039C87F0C806A896572D1E78ED6A7"
  local pgp_signing_key_fingerprint="143EE89AAC97053810D13E378A7E8CA85A62CF20"

  ensure_not_sudo

  configure_bash

  install_basics
  install_git
  install_github_cli
  install_rust
  install_python
  install_cpp_toolchains
  install_cmake
  install_yubico_utilities
  install_golang
  install_pijul
  install_nodejs
  install_tex_live
  install_chrome
  install_brave
  install_jetbrains_toolbox "${jetbrains_toolbox_tar_gz}"

  configure_gpg "${pgp_primary_key_fingerprint}"
  configure_git "${pgp_signing_key_fingerprint}"

  log_info "Success! Reboot required."
}

# Entry point
main "$1"
