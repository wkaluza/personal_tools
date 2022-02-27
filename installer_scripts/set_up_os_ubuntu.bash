#!/usr/bin/env bash

set -euo pipefail

THIS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

source "${THIS_SCRIPT_DIR}/../shell_script_imports/logging.bash"
source "${THIS_SCRIPT_DIR}/../shell_script_imports/common.bash"

JETBRAINS_TOOLBOX_TAR_GZ_PATH="does_not_exist"
CHROME_DEB_PATH="does_not_exist"

function on_exit
{
  local exit_code=$?

  if [[ $exit_code -eq 0 ]]; then
    rm -f "${JETBRAINS_TOOLBOX_TAR_GZ_PATH}"
    rm -f "${CHROME_DEB_PATH}"
  fi

  exit $exit_code
}

trap on_exit EXIT

function install_basics
{
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
    inotify-tools \
    rdfind \
    jq \
    mercurial \
    darcs \
    fossil \
    subversion \
    dislocker \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    vim \
    curl \
    wget
}

function install_gnupg
{
  print_trace

  DEBIAN_FRONTEND=noninteractive sudo \
    --preserve-env=DEBIAN_FRONTEND apt-get install -y \
    gnupg

  echo $'SSH_AUTH_SOCK="$(gpgconf --list-dirs | grep ssh | sed -n \'s/.*:\(\/.*$\)/\\1/p\')"' >>"${HOME}/.bashrc"
}

function install_git
{
  print_trace

  sudo add-apt-repository -y ppa:git-core/ppa
  sudo apt-get update

  DEBIAN_FRONTEND=noninteractive sudo \
    --preserve-env=DEBIAN_FRONTEND apt-get install -y \
    git
}

function install_github_cli
{
  print_trace

  local key="/usr/share/keyrings/githubcli-archive-keyring.gpg"
  local url="https://cli.github.com/packages"

  curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg |
    sudo gpg --dearmor -o "${key}"
  echo "deb [arch=amd64 signed-by=${key}] ${url} stable main" |
    sudo tee /etc/apt/sources.list.d/github-cli.list

  sudo apt-get update
  DEBIAN_FRONTEND=noninteractive sudo \
    --preserve-env=DEBIAN_FRONTEND apt-get install -y \
    gh

  echo 'eval "$(gh completion --shell bash)"'
}

function install_rust
{
  print_trace

  curl --proto '=https' --tlsv1.2 -sSf "https://sh.rustup.rs" | sh -s -- -y
  source "${HOME}/.cargo/env"
  rustup update

  echo 'eval "$(rustup completions bash)"' >>"${HOME}/.bashrc"
}

function install_python
{
  print_trace

  local poetry_url="https://raw.githubusercontent.com/python-poetry/poetry/master/install-poetry.py"
  local poetry_bash_completion="/etc/bash_completion.d/poetry.bash-completion"

  DEBIAN_FRONTEND=noninteractive sudo \
    --preserve-env=DEBIAN_FRONTEND apt-get install -y \
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

function install_cpp_toolchains
{
  print_trace

  DEBIAN_FRONTEND=noninteractive sudo \
    --preserve-env=DEBIAN_FRONTEND apt-get install -y \
    make \
    ninja-build \
    gcc-10 \
    g++-10 \
    lldb-12 \
    clang-12 \
    libclang-12-dev \
    clang-tools-12 \
    clang-format-12 \
    clang-tidy-12
}

function install_cmake
{
  print_trace

  DEBIAN_FRONTEND=noninteractive sudo \
    --preserve-env=DEBIAN_FRONTEND apt-get install -y \
    apt-transport-https \
    ca-certificates \
    gnupg \
    software-properties-common \
    wget

  local url="https://apt.kitware.com/keys/kitware-archive-latest.asc"
  local temp_keyring="/usr/share/keyrings/kitware-archive-keyring.gpg"

  curl -fsSL "${url}" 2>/dev/null |
    gpg --dearmor - |
    sudo tee "${temp_keyring}" >/dev/null

  echo "deb [signed-by=${temp_keyring}] https://apt.kitware.com/ubuntu/ $(lsb_release -cs) main" |
    sudo tee /etc/apt/sources.list.d/kitware.list >/dev/null

  sudo apt-get update

  sudo rm -rf "${temp_keyring}"

  # Automate key rotation
  DEBIAN_FRONTEND=noninteractive sudo \
    --preserve-env=DEBIAN_FRONTEND apt-get install -y \
    kitware-archive-keyring

  DEBIAN_FRONTEND=noninteractive sudo \
    --preserve-env=DEBIAN_FRONTEND apt-get install -y \
    cmake
}

function install_jetbrains_toolbox
{
  print_trace

  local install_destination="/opt/jetbrains/jetbrains-toolbox"

  if test -x "${install_destination}"; then
    log_info "jetbrains-toolbox already installed at ${install_destination}"
  else
    sudo mkdir --parents "$(dirname "${install_destination}")"

    pushd "$(dirname "${JETBRAINS_TOOLBOX_TAR_GZ_PATH}")" >/dev/null
    tar -xzf "${JETBRAINS_TOOLBOX_TAR_GZ_PATH}"

    local extracted_dir
    extracted_dir="$(find . -type d -name 'jetbrains-toolbox-*')"

    sudo cp \
      "${extracted_dir}/$(basename "${install_destination}")" \
      "${install_destination}"

    rm -rf "${extracted_dir}"
    popd >/dev/null
  fi

  if ! test -x "${install_destination}"; then
    log_error "Something went wrong when installing jetbrains-toolbox"
    exit 1
  fi
}

function install_yubico_utilities
{
  print_trace

  sudo add-apt-repository -y ppa:yubico/stable
  sudo apt-get update
  DEBIAN_FRONTEND=noninteractive sudo \
    --preserve-env=DEBIAN_FRONTEND apt-get install -y \
    yubikey-manager \
    yubioath-desktop \
    yubikey-personalization-gui
}

function install_golang
{
  print_trace

  local go_archive="go.tar.gz"
  local v="1.17.2"
  local download_url="https://dl.google.com/go/go${v}.linux-amd64.tar.gz"
  local target_dir="/usr/local"

  if test -d "${target_dir}/go"; then
    echo "golang is already installed"
    go version
  else
    curl -fsSL --output "./${go_archive}" "${download_url}"
    sudo mv "./${go_archive}" "${target_dir}"

    pushd "${target_dir}" >/dev/null
    sudo tar -xzf "./${go_archive}"
    sudo rm "./${go_archive}"
    popd >/dev/null

    echo 'export GOROOT="/usr/local/go"' >>"${HOME}/.bashrc"
    echo 'export GOPATH="${HOME}/go"' >>"${HOME}/.bashrc"
    echo 'export GOPRIVATE="github.com/wkaluza/*"' >>"${HOME}/.bashrc"
    echo 'export CGO_ENABLED=0' >>"${HOME}/.bashrc"
    echo 'export PATH="$PATH:${GOROOT}/bin:${GOPATH}/bin"' >>"${HOME}/.bashrc"
  fi
}

function install_pijul
{
  print_trace

  local pijul_version="~1.0.0-alpha"

  sudo apt-get -y install \
    make \
    libsodium-dev \
    pkg-config \
    libssl-dev \
    libxxhash-dev \
    libzstd-dev

  cargo search pijul
  cargo install pijul --version "${pijul_version}"
}

function install_nodejs
{
  print_trace

  curl -sL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
  DEBIAN_FRONTEND=noninteractive sudo \
    --preserve-env=DEBIAN_FRONTEND apt-get install -y \
    nodejs

  npm config set ignore-scripts true
}

function install_tex_live
{
  print_trace

  DEBIAN_FRONTEND=noninteractive sudo \
    --preserve-env=DEBIAN_FRONTEND apt-get install -y \
    texlive-full
}

function install_chrome
{
  print_trace

  local url="https://dl.google.com/linux/direct"

  DEBIAN_FRONTEND=noninteractive sudo \
    --preserve-env=DEBIAN_FRONTEND apt-get install -y \
    fonts-liberation

  if test -x "/opt/google/chrome/google-chrome"; then
    log_info "Google Chrome already installed"
  else
    CHROME_DEB_PATH="${THIS_SCRIPT_DIR}/../chrome_$(date --utc +'%Y%m%d%H%M%S%N')___.deb"

    wget --output-document "${CHROME_DEB_PATH}" \
      "${url}/google-chrome-stable_current_amd64.deb"
    sudo dpkg --install "${CHROME_DEB_PATH}"
  fi

  google-chrome --version
}

function install_brave
{
  print_trace

  local key="/usr/share/keyrings/brave-browser-archive-keyring.gpg"
  local url="https://brave-browser-apt-release.s3.brave.com"

  DEBIAN_FRONTEND=noninteractive sudo \
    --preserve-env=DEBIAN_FRONTEND apt-get install -y \
    apt-transport-https \
    curl

  sudo curl -fsSL -o "${key}" "${url}/brave-browser-archive-keyring.gpg"
  echo "deb [arch=amd64 signed-by=${key}] ${url} stable main" |
    sudo tee /etc/apt/sources.list.d/brave-browser-release.list

  sudo apt-get update
  DEBIAN_FRONTEND=noninteractive sudo \
    --preserve-env=DEBIAN_FRONTEND apt-get install -y \
    brave-browser

  brave-browser --version
}

function install_heroku_cli
{
  print_trace

  local apt_url="https://cli-assets.heroku.com/apt"

  echo "deb ${apt_url} ./" |
    sudo tee /etc/apt/sources.list.d/heroku.list

  curl "https://cli-assets.heroku.com/apt/release.key" |
    sudo APT_KEY_DONT_WARN_ON_DANGEROUS_USAGE="DontWarn" \
      apt-key add -

  sudo apt-get update
  DEBIAN_FRONTEND=noninteractive sudo \
    --preserve-env=DEBIAN_FRONTEND apt-get install -y \
    heroku

  echo "heroku installed to $(which heroku)"
  heroku version

  printf "$(heroku autocomplete:script bash)" >>"$HOME/.bashrc"
  source "$HOME/.bashrc"
}

function install_inkscape
{
  print_trace

  DEBIAN_FRONTEND=noninteractive sudo \
    --preserve-env=DEBIAN_FRONTEND apt-get install -y \
    inkscape \
    libcanberra-gtk-module \
    libcanberra-gtk3-module
}

function configure_bash
{
  print_trace

  local config_preamble="# WK workstation setup"
  local bashrc_path="$HOME/.bashrc"

  if test -f "${bashrc_path}" &&
    grep --silent "^${config_preamble}$" "${bashrc_path}"; then
    log_info "bash already configured"
  else
    echo "${config_preamble}" >>"${bashrc_path}"
    cat "${THIS_SCRIPT_DIR}/bashrc_append.bash" >>"${bashrc_path}"
  fi
}

function configure_git
{
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

  git config --global advice.detachedHead false
}

function configure_gpg
{
  print_trace

  local pgp_primary_key_fingerprint="$1"

  local gpg_home="$HOME/.gnupg"
  local gpg_config_dir="gpg_config"

  mkdir --parents "$gpg_home"
  cp "${THIS_SCRIPT_DIR}/${gpg_config_dir}/gpg.conf" "${gpg_home}"
  cp "${THIS_SCRIPT_DIR}/${gpg_config_dir}/gpg-agent.conf" "${gpg_home}"
  chmod u+rwx,go-rwx "${gpg_home}"

  gpg --receive-keys "${pgp_primary_key_fingerprint}"
  # Set trust to ultimate
  echo "${pgp_primary_key_fingerprint}:6:" | gpg --import-ownertrust

  # Import GitHub's public key
  gpg --fetch-keys "https://github.com/web-flow.gpg"
}

function disable_swap
{
  sudo swapoff --all
  cat /etc/fstab | grep -v ' swap ' | sudo tee /etc/fstab
}

function main
{
  JETBRAINS_TOOLBOX_TAR_GZ_PATH="$(realpath "$1")"

  if ! test -f "${JETBRAINS_TOOLBOX_TAR_GZ_PATH}"; then
    log_error "Invalid path to jetbrains-toolbox archive: ${JETBRAINS_TOOLBOX_TAR_GZ_PATH}"
    exit 1
  fi

  local pgp_primary_key_fingerprint="174C9368811039C87F0C806A896572D1E78ED6A7"
  local pgp_signing_key_fingerprint="143EE89AAC97053810D13E378A7E8CA85A62CF20"

  ensure_not_sudo

  configure_bash

  install_basics
  install_gnupg
  install_git
  install_github_cli
  install_rust
  install_python
  install_cpp_toolchains
  install_cmake
  install_yubico_utilities
  install_golang
  # install_pijul # requires cpp_toolchains and rust
  install_nodejs
  install_tex_live
  install_chrome
  install_brave
  install_heroku_cli
  install_inkscape
  install_jetbrains_toolbox

  configure_gpg "${pgp_primary_key_fingerprint}"
  configure_git "${pgp_signing_key_fingerprint}"

  disable_swap

  log_info "Success! Reboot required."
}

# Entry point
main "$1"
