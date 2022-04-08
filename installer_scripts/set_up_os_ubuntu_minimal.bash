set -euo pipefail
shopt -s inherit_errexit

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

  exit "${exit_code}"
}

trap on_exit EXIT

function install_basics
{
  print_trace

  sudo apt-get update
  sudo apt-get upgrade --with-new-pkgs --yes
  sudo apt-get install --yes \
    apt-transport-https \
    ca-certificates \
    curl \
    gettext-base \
    rdfind \
    rng-tools \
    rsync \
    vim \
    wget

  sudo apt-get install --yes \
    meld \
    vlc
}

function install_latest_git
{
  print_trace

  sudo apt-get install --yes \
    software-properties-common

  sudo add-apt-repository --yes ppa:git-core/ppa
  sudo apt-get update

  sudo apt-get install --yes \
    git
}

function install_github_cli
{
  print_trace

  if gh --version >/dev/null; then
    log_info "GitHub CLI is already installed"
  else
    local key="/usr/share/keyrings/githubcli-archive-keyring.gpg"
    local url="https://cli.github.com/packages"

    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg |
      sudo gpg --dearmor -o "${key}"
    echo "deb [arch=$(dpkg --print-architecture) signed-by=${key}] ${url} stable main" |
      sudo tee /etc/apt/sources.list.d/github-cli.list

    sudo apt-get update
    sudo apt-get install --yes \
      gh
  fi
}

function install_jetbrains_toolbox
{
  print_trace

  sudo apt-get install --yes \
    libfuse2

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

    local uid="$(id -u)"
    local gid="$(id -g)"

    sudo chown "${uid}:${gid}" "${install_destination}"
  fi
}

function install_yubico_utilities
{
  print_trace

  sudo apt-get install --yes \
    curl \
    libfuse2 \
    pcscd

  local installation_dir="/opt/yubico"

  local auth_name="yubioath-desktop"
  local mgr_name="yubikey-manager-qt"

  local url_prefix="https://developers.yubico.com"

  local auth_url="${url_prefix}/${auth_name}/Releases/${auth_name}-latest-linux.AppImage"
  local mgr_url="${url_prefix}/${mgr_name}/Releases/${mgr_name}-latest-linux.AppImage"

  sudo mkdir --parents "${installation_dir}"

  sudo curl \
    -fsSL \
    --output "${installation_dir}/${auth_name}" \
    "${auth_url}"

  sudo curl \
    -fsSL \
    --output "${installation_dir}/${mgr_name}" \
    "${mgr_url}"

  local uid="$(id -u)"
  local gid="$(id -g)"

  sudo chmod "u+x" \
    "${installation_dir}/${auth_name}" \
    "${installation_dir}/${mgr_name}"
  sudo chown "${uid}:${gid}" \
    "${installation_dir}/${auth_name}" \
    "${installation_dir}/${mgr_name}"

  sudo apt-get install --yes \
    libpcsclite-dev \
    python3-dev \
    python3-pip \
    python3-venv \
    swig

  python3 -m pip install --upgrade pip
  python3 -m pip install yubikey-manager
}

function install_chrome
{
  print_trace

  if google-chrome --version >/dev/null; then
    log_info "Chrome is already installed"
  else
    local url="https://dl.google.com/linux/direct"

    sudo apt-get install --yes \
      fonts-liberation

    if test -x "/opt/google/chrome/google-chrome"; then
      log_info "Google Chrome already installed"
    else
      CHROME_DEB_PATH="${THIS_SCRIPT_DIR}/../chrome_$(date --utc +'%Y%m%d%H%M%S%N')___.deb"

      wget --output-document "${CHROME_DEB_PATH}" \
        "${url}/google-chrome-stable_current_amd64.deb"
      sudo dpkg --install "${CHROME_DEB_PATH}"
    fi
  fi
}

function install_brave
{
  print_trace

  if brave-browser --version >/dev/null; then
    log_info "Brave is already installed"
  else
    local key="/usr/share/keyrings/brave-browser-archive-keyring.gpg"
    local url="https://brave-browser-apt-release.s3.brave.com"

    sudo apt-get install --yes \
      apt-transport-https \
      curl

    sudo curl -fsSL -o "${key}" "${url}/brave-browser-archive-keyring.gpg"
    echo "deb [arch=$(dpkg --print-architecture) signed-by=${key}] ${url} stable main" |
      sudo tee /etc/apt/sources.list.d/brave-browser-release.list

    sudo apt-get update
    sudo apt-get install --yes \
      brave-browser
  fi
}

function install_heroku_cli
{
  print_trace

  sudo apt-get install --yes \
    snapd

  if heroku --version >/dev/null; then
    log_info "Heroku CLI already installed"
  else
    sudo snap install --classic heroku
  fi
}

function install_inkscape
{
  print_trace

  sudo apt-get install --yes \
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
  git config --global advice.fetchShowForcedUpdates false

  git config --global fetch.showForcedUpdates false
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
  install_latest_git
  # install_github_cli
  # install_yubico_utilities
  install_chrome
  install_brave
  # install_heroku_cli
  install_inkscape
  install_jetbrains_toolbox

  configure_gpg "${pgp_primary_key_fingerprint}"
  configure_git "${pgp_signing_key_fingerprint}"

  disable_swap

  log_info "Success: $(basename "$0")"
  log_info "Reboot required."
}

# Entry point
main "$1"
