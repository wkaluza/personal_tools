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

function ensure_not_sudo
{
  print_trace

  if test "0" -eq "$(id -u)"; then
    log_error "Do not run this as root"
    exit 1
  fi
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

  sudo apt-get upgrade --yes --with-new-pkgs
}

function prepare_gnupg
{
  print_trace

  sudo apt-get install --yes \
    gnupg \
    scdaemon

  gpgconf --kill gpg-agent scdaemon

  local primary_key_fingerprint="174C9368811039C87F0C806A896572D1E78ED6A7"
  local gpg_url="https://keys.openpgp.org/vks/v1/by-fingerprint/${primary_key_fingerprint}"

  if ! gpg --card-status | grep "${gpg_url}" >/dev/null; then
    echo "Error: Insert smartcard"
    exit 1
  fi

  gpg --fetch-keys "${gpg_url}"

  echo "${primary_key_fingerprint}:6:" | gpg --import-ownertrust

  gpgconf --kill gpg-agent scdaemon

  gpg --list-keys >/dev/null
  gpg --list-secret-keys >/dev/null

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

  TEMP_DIR="$(realpath "${HOME}/wk_personal_tools_temp")"
  local url="git@github.com:wkaluza/personal_tools.git"

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

  prepare_apt
  prepare_gnupg
  prepare_umask_and_home_permissions

  clone_personal_tools

  set_up_pass

  bash "${TEMP_DIR}/installer_scripts/install_docker.bash"
  bash "${TEMP_DIR}/installer_scripts/configure_docker.bash"

  bash "${TEMP_DIR}/startup.bash"
  rm -rf "${TEMP_DIR}"

  log_info "Success: $(basename $0)"
}

main
