set -euo pipefail
if command -v shopt &>/dev/null; then
  shopt -s inherit_errexit
fi
THIS_SCRIPT_DIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"
cd "${THIS_SCRIPT_DIR}"

source "${THIS_SCRIPT_DIR}/../shell_script_imports/preamble.bash"

PRIMARY_KEY_FINGERPRINT="174C9368811039C87F0C806A896572D1E78ED6A7"
SIGNING_KEY_FINGERPRINT="143EE89AAC97053810D13E378A7E8CA85A62CF20"
BASHRC_PATH="${HOME}/.bashrc"

function prime_sudo_password_cache
{
  print_trace

  quiet sudo ls "${HOME}"
}

function disable_swap
{
  print_trace

  local fstab_file="/etc/fstab"
  local temp_file
  temp_file="$(mktemp)"

  sudo swapoff --all
  cat "${fstab_file}" >"${temp_file}"
  cat "${temp_file}" | grep -v ' swap ' | quiet sudo tee "${fstab_file}"
}

function prepare_apt
{
  print_trace

  sudo apt-get update

  sudo apt-get install --yes --no-install-recommends \
    apt-utils

  DEBIAN_FRONTEND=noninteractve sudo --preserve-env=DEBIAN_FRONTEND \
    apt-get install --yes \
    keyboard-configuration \
    tzdata

  if [[ "${HOST_TIMEZONE:-"___timezone_not_defined___"}" != "___timezone_not_defined___" ]]; then
    if test -f "$(readlink -e "${HOST_TIMEZONE}")"; then
      sudo ln -fs "${HOST_TIMEZONE}" "/etc/localtime"
      sudo dpkg-reconfigure --frontend noninteractive tzdata
    fi
  fi

  sudo apt-get upgrade --yes --with-new-pkgs

  sudo apt-get install --yes \
    apt-transport-https \
    ca-certificates \
    software-properties-common
}

function install_rng_tools
{
  print_trace

  sudo apt-get install --yes \
    rng-tools
}

function install_mkcert
{
  print_trace

  sudo apt-get install --yes \
    libnss3-tools \
    mkcert
}

function install_xxd
{
  print_trace

  sudo apt-get install --yes \
    xxd
}

function install_openssl
{
  print_trace

  sudo apt-get install --yes \
    openssl
}

function prepare_gnupg
{
  print_trace

  sudo apt-get install --yes \
    gnupg \
    scdaemon

  local gpg_home="${HOME}/.gnupg"

  mkdir --parents "${gpg_home}"

  cat <<EOF >"${gpg_home}/gpg.conf"
utf8-strings
no-emit-version
no-comments
export-options export-minimal

keyid-format long
with-fingerprint
with-fingerprint
with-keygrip

list-options show-uid-validity
verify-options show-uid-validity

personal-cipher-preferences AES256
personal-digest-preferences SHA512 SHA256
personal-compress-preferences ZLIB BZIP2 ZIP
default-preference-list SHA512 SHA384 SHA256 AES256 AES TWOFISH ZLIB BZIP2 ZIP Uncompressed

cipher-algo AES256
digest-algo SHA512
cert-digest-algo SHA512
compress-algo ZLIB

disable-cipher-algo 3DES
weak-digest SHA1

s2k-cipher-algo AES256
s2k-digest-algo SHA512
s2k-mode 3
s2k-count 65011712
EOF

  cat <<EOF >"${gpg_home}/gpg-agent.conf"
default-cache-ttl 14400
max-cache-ttl 86400
EOF

  chmod u+rwx,go-rwx "${gpg_home}"

  gpgconf --kill gpg-agent scdaemon

  quiet gpg --list-keys
  quiet gpg --list-secret-keys

  gpg --receive-keys "${PRIMARY_KEY_FINGERPRINT}"
  # Set trust to ultimate
  echo "${PRIMARY_KEY_FINGERPRINT}:6:" | gpg --import-ownertrust

  # Import GitHub's public key
  gpg --fetch-keys "https://github.com/web-flow.gpg"

  gpg --list-keys
  gpg --list-secret-keys

  gpgconf --kill gpg-agent scdaemon

  echo $'export SSH_AUTH_SOCK="$(gpgconf --list-dirs |' \
    $'grep agent-ssh-socket |' \
    $'sed \'s/^agent-ssh-socket:\(.*\)$/\\1/\')"' >>"${BASHRC_PATH}"

  source "${BASHRC_PATH}"

  local primary_key_length
  primary_key_length="$(echo -n "${PRIMARY_KEY_FINGERPRINT}" |
    wc -c)"
  local primary_key_short
  primary_key_short="$(echo -n "${PRIMARY_KEY_FINGERPRINT}" |
    cut -c "$((primary_key_length - 15))-${primary_key_length}")"

  if gpg --card-status | quiet grep "${primary_key_short}"; then
    log_info "Smart card detected"
  else
    log_info "Smart card not detected"
  fi
}

function set_umask_and_home_permissions
{
  print_trace

  if [[ "$(umask)" != "0077" ]]; then
    find "${HOME}" \
      -user "$(id -un)" \
      -group "$(id -gn)" \
      \( -type f -or -type d \) \
      -exec chmod "g-rwx,o-rwx" -- {} \;
  fi

  echo 'umask 0077' >>"${BASHRC_PATH}"

  source "${BASHRC_PATH}"
}

function install_configure_ufw
{
  sudo apt-get install --yes \
    ufw

  sudo ufw enable
  sudo ufw default deny incoming
  sudo ufw default allow outgoing
  sudo ufw default deny routed
}

function clone_personal_tools
{
  print_trace

  local tools_dir="$1"

  local url="ssh://git@github.com/wkaluza/personal_tools.git"

  clone_or_fetch \
    "${url}" \
    "${tools_dir}"
}

function set_up_pass
{
  print_trace

  sudo apt-get install --yes \
    pass

  pass init "${PRIMARY_KEY_FINGERPRINT}"
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

function configure_git
{
  print_trace

  git config --global user.email "wkaluza@protonmail.com"
  git config --global user.name "Wojciech Kaluza"

  git config --global init.defaultBranch main

  git config --global rebase.autosquash true
  git config --global pull.ff only
  git config --global merge.ff false

  git config --global log.showSignature true

  git config --global user.signingKey "${SIGNING_KEY_FINGERPRINT}"
  git config --global gpg.program gpg

  git config --global commit.gpgSign true
  git config --global merge.verifySignatures true

  git config --global rerere.enabled true

  git config --global advice.detachedHead false
  git config --global advice.fetchShowForcedUpdates false
  git config --global advice.skippedCherryPicks false

  git config --global fetch.showForcedUpdates false
}

function configure_git_ssh_substitutions
{
  print_trace

  git config --global url."ssh://git@github.com/".insteadOf "https://github.com/"
}

function ensure_user_is_in_docker_group
{
  print_trace

  if ! groups | quiet grep docker; then
    # Create the docker group if it does not exist
    getent group docker || sudo addgroup --system docker

    sudo adduser "$(id -un)" docker
    log_info "User added to docker group"
    log_info "Log out and back in for change to take effect"

    exit 1
  fi
}

function configure_bash
{
  print_trace

  local config_preamble="# WK workstation setup"
  local bashrc_path="${HOME}/.bashrc"

  if test -f "${bashrc_path}" &&
    grep --silent "^${config_preamble}$" "${bashrc_path}"; then
    log_info "bash already configured"
  else
    cat <<EOF >>"${bashrc_path}"
${config_preamble}
shopt -s histappend
shopt -s cmdhist
export HISTFILESIZE=1000000
export HISTSIZE=1000000
export HISTIGNORE="pwd:top:ps"
export HISTCONTROL=ignorespace:erasedups
export PROMPT_COMMAND="history -n ; history -a"

PS1="----------------------------------------\n\u@\H\n\\\$(pwd)\n\\\$ "
EOF

    source "${bashrc_path}"
  fi
}

function manage_sudo_password_in_pass
{
  print_trace

  local script_dir="${HOME}/.local/bin"

  cat <<'EOF' >"${script_dir}/sudo_askpass"
#!/usr/bin/env bash

function main
{
  pass show "sudo_$(whoami)_at_$(hostname)"
}

main
EOF

  cat <<'EOF' >"${script_dir}/sudo"
#!/usr/bin/env bash

THIS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

function main
{
  env \
    SUDO_ASKPASS="${THIS_SCRIPT_DIR}/sudo_askpass" \
    /usr/bin/sudo \
    --askpass \
    "$@"
}

main "$@"
EOF

  chmod 700 \
    "${script_dir}/sudo_askpass" \
    "${script_dir}/sudo"
}

function install_minikube
{
  print_trace

  local version="v1.27.1"
  local minikube_path="/usr/local/bin/minikube"

  sudo wget \
    -q \
    -O "${minikube_path}" \
    "https://storage.googleapis.com/minikube/releases/${version}/minikube-linux-amd64"
  sudo chmod +x "${minikube_path}"
}

function install_kind
{
  print_trace

  local output_path="${HOME}/.local/bin/kind"
  local version="v0.17.0"

  curl \
    --location \
    --output "${output_path}" \
    --silent \
    "https://kind.sigs.k8s.io/dl/${version}/kind-linux-amd64"

  chmod "u+x" "${output_path}"
}

function install_flux_cli
{
  print_trace

  local url="https://github.com/fluxcd/flux2/releases/download"
  local version="0.36.0"
  local executable_name="flux"

  local output_path="${HOME}/.local/bin/${executable_name}"

  mkdir --parents "$(dirname "${output_path}")"

  local temp_dir_archive
  temp_dir_archive="$(mktemp -d)"
  local archive_path="${temp_dir_archive}/${executable_name}.tar.gz"

  local temp_dir_decompressed
  temp_dir_decompressed="$(mktemp -d)"
  local executable_path="${temp_dir_decompressed}/${executable_name}"

  wget \
    -q \
    -O "${archive_path}" \
    "${url}/v${version}/${executable_name}_${version}_linux_amd64.tar.gz"

  untar_gzip_to \
    "${archive_path}" \
    "${temp_dir_decompressed}"

  if test -f "${executable_path}"; then
    mv \
      "${executable_path}" \
      "${output_path}"
    chmod u+x "${output_path}"
  else
    log_error "File not found: ${executable_path}"
    exit 1
  fi
}

function install_kubectl
{
  print_trace

  local output_path="${HOME}/.local/bin/kubectl"
  local version="v1.25.2"
  # version="$(curl -L -s https://dl.k8s.io/release/stable.txt)"

  curl \
    --location \
    --output "${output_path}" \
    --silent \
    "https://dl.k8s.io/release/${version}/bin/linux/amd64/kubectl"

  chmod "u+x" "${output_path}"
}

function main
{
  local tools_dir
  tools_dir="$(realpath "${HOME}/.wk_tools___")"

  ensure_not_sudo
  prime_sudo_password_cache
  ensure_user_is_in_docker_group

  configure_bash

  prepare_apt

  install_rng_tools
  install_openssl
  install_xxd
  install_mkcert

  prepare_gnupg

  install_latest_git
  configure_git

  clone_personal_tools \
    "${tools_dir}"

  set_up_pass

  disable_swap

  bash "${THIS_SCRIPT_DIR}/install_docker.bash"
  bash "${THIS_SCRIPT_DIR}/configure_docker.bash"

  bash "${THIS_SCRIPT_DIR}/install_applications.bash"

  install_kind
  install_minikube
  install_kubectl
  install_flux_cli

  # This has to be done late in the setup process
  # or it interferes with docker testing
  configure_git_ssh_substitutions

  set_umask_and_home_permissions

  manage_sudo_password_in_pass

  install_configure_ufw

  log_info "Success: $(basename "$0")"
}

main
