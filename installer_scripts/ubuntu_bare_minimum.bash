set -euo pipefail
shopt -s inherit_errexit

PRIMARY_KEY_FINGERPRINT="174C9368811039C87F0C806A896572D1E78ED6A7"
SIGNING_KEY_FINGERPRINT="143EE89AAC97053810D13E378A7E8CA85A62CF20"
BASHRC_PATH="${HOME}/.bashrc"
TEMP_DIR="___not_a_real_path___"
ERR_JETBRAINS_PATH_NOT_SET="___ERR_JETBRAINS_PATH_NOT_SET___"

function log_info
{
  local message="$1"

  echo "INFO: ${message}"
}

function log_warning
{
  local message="$1"

  echo "WARNING: ${message}"
}

function log_error
{
  local message="$1"

  echo "ERROR: ${message}"
}

function print_trace
{
  local func="${FUNCNAME[1]}"
  local line="${BASH_LINENO[1]}"
  local file="${BASH_SOURCE[2]}"

  local trace="Entered ${func} on line ${line} of ${file}"

  echo "[***TRACE***]: ${trace}"
}

function prime_sudo_password_cache
{
  print_trace

  sudo ls "${HOME}" >/dev/null
}

function ensure_not_sudo
{
  print_trace

  if test "0" -eq "$(id -u)"; then
    log_error "Do not run this as root"
    exit 1
  fi
}

function disable_swap
{
  print_trace

  sudo swapoff --all
  cat /etc/fstab | grep -v ' swap ' | sudo tee /etc/fstab >/dev/null
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

  gpg --list-keys >/dev/null
  gpg --list-secret-keys >/dev/null

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

  if gpg --card-status | grep "${primary_key_short}" >/dev/null; then
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

function clone_personal_tools
{
  print_trace

  sudo apt-get install --yes \
    git

  TEMP_DIR="$(realpath "${HOME}/wk_personal_tools___deleteme")"
  local url="https://github.com/wkaluza/personal_tools.git"

  if ! test -d "${TEMP_DIR}"; then
    git clone \
      --recurse-submodules \
      --tags \
      "${url}" \
      "${TEMP_DIR}"
  fi
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

  git config --global fetch.showForcedUpdates false
}

function configure_git_ssh_substitutions
{
  print_trace

  git config --global url."git@github.com:".insteadOf "https://github.com/"
}

function ensure_user_is_in_docker_group
{
  print_trace

  if ! groups | grep docker >/dev/null; then
    # Create the docker group if it does not exist
    getent group docker || sudo addgroup --system docker

    sudo adduser "${USER}" docker
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
HISTFILESIZE=1000000
HISTSIZE=1000000
HISTIGNORE="pwd:top:ps"
HISTCONTROL=ignorespace:erasedups
PROMPT_COMMAND="history -n ; history -a"

export HISTFILESIZE \
  HISTSIZE \
  HISTIGNORE \
  HISTCONTROL \
  PROMPT_COMMAND
EOF

    source "${bashrc_path}"
  fi
}

function main
{
  local jetbrains_toolbox_tar_gz
  jetbrains_toolbox_tar_gz="$(realpath "$1")"

  if [[ "$(basename "${jetbrains_toolbox_tar_gz}")" == "${ERR_JETBRAINS_PATH_NOT_SET}" ]]; then
    log_error "Path to jetbrains toolbox tar.gz archive required as argument"
    exit 1
  fi

  if ! test -f "${jetbrains_toolbox_tar_gz}"; then
    log_error "File not found: ${jetbrains_toolbox_tar_gz}"
    exit 1
  fi

  ensure_not_sudo
  prime_sudo_password_cache
  ensure_user_is_in_docker_group

  configure_bash

  prepare_apt

  install_rng_tools

  prepare_gnupg

  install_latest_git
  configure_git

  clone_personal_tools

  set_up_pass

  disable_swap

  bash "${TEMP_DIR}/installer_scripts/install_docker.bash"
  bash "${TEMP_DIR}/installer_scripts/configure_docker.bash"

  bash "${TEMP_DIR}/installer_scripts/install_jetbrains.bash" \
    "${jetbrains_toolbox_tar_gz}"
  bash "${TEMP_DIR}/installer_scripts/install_applications.bash"

  # This has to be done late in the setup process
  # or it interferes with docker testing
  configure_git_ssh_substitutions

  set_umask_and_home_permissions

  log_info "Success: $(basename "$0")"
}

main "${1-"${ERR_JETBRAINS_PATH_NOT_SET}"}"
