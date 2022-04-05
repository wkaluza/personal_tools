set -euo pipefail

PRIMARY_KEY_FINGERPRINT="174C9368811039C87F0C806A896572D1E78ED6A7"
BASHRC_PATH="${HOME}/.bashrc"
THIS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
TEMP_DIR="___not_a_real_path___"

function log_info
{
  local message="$1"

  echo "INFO: $message"
}

function log_warning
{
  local message="$1"

  echo "WARNING: $message"
}

function log_error
{
  local message="$1"

  echo "ERROR: $message"
}

function print_trace
{
  local func="${FUNCNAME[1]}"
  local line="${BASH_LINENO[1]}"
  local file="${BASH_SOURCE[2]}"

  local trace="Entered ${func} on line ${line} of ${file}"

  echo "[***TRACE***]: $trace"
}

function prime_sudo_password_cache
{
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

  until gpg --card-status |
    grep "${PRIMARY_KEY_FINGERPRINT}" >/dev/null; do
    log_error "Insert smartcard..."
    sleep 5
  done

  gpg --receive-keys "${PRIMARY_KEY_FINGERPRINT}"

  # Set trust to ultimate
  echo "${PRIMARY_KEY_FINGERPRINT}:6:" | gpg --import-ownertrust

  # Import GitHub's public key
  gpg --fetch-keys "https://github.com/web-flow.gpg"

  gpgconf --kill gpg-agent scdaemon

  echo $'export SSH_AUTH_SOCK="$(gpgconf --list-dirs |' \
    $'grep agent-ssh-socket |' \
    $'sed \'s/^agent-ssh-socket:\(.*\)$/\\1/\')"' >>"${BASHRC_PATH}"

  source "${BASHRC_PATH}"
}

function prepare_umask_and_home_permissions
{
  print_trace

  chmod --recursive "g-rwx,o-rwx" "${HOME}"

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

function main
{
  ensure_not_sudo
  prime_sudo_password_cache

  prepare_apt
  prepare_gnupg
  prepare_umask_and_home_permissions

  clone_personal_tools

  set_up_pass

  disable_swap

  bash "${TEMP_DIR}/installer_scripts/install_docker.bash"
  bash "${TEMP_DIR}/installer_scripts/configure_docker.bash"

  bash "${TEMP_DIR}/startup.bash"
  rm -rf "${TEMP_DIR}"

  log_info "Success: $(basename $0)"
}

main
