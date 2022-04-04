set -euo pipefail

BASHRC_PATH="${HOME}/.bashrc"
STARTUP_SCRIPT="___not_a_real_path___"
THIS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

function ensure_not_sudo
{
  if test "0" -eq "$(id -u)"; then
    echo "Do not run this as root"
    exit 1
  fi
}

function prepare_apt
{
  sudo apt-get update
  sudo apt-get upgrade --yes --with-new-pkgs
}

function prepare_gnupg
{
  sudo apt-get install --yes \
    gnupg \
    scdaemon

  gpgconf --kill gpg-agent scdaemon

  local primary_key_fingerprint="174C9368811039C87F0C806A896572D1E78ED6A7"
  local gpg_url="https://keys.openpgp.org/vks/v1/by-fingerprint/${primary_key_fingerprint}}"

  if ! gpg --card-status | grep "${gpg_url}" >dev/null; then
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
  chmod --recursive "g-rwx,o-rwx" "${HOME}"

  echo 'umask 0077' >>"${BASHRC_PATH}"

  source "${BASHRC_PATH}"
}

function clone_personal_tools
{
  sudo apt-get install --yes \
    git

  temp_dir="$(realpath "${HOME}/wk_personal_tools_temp")"
  local url="git@github.com:wkaluza/personal_tools.git"

  STARTUP_SCRIPT="${temp_dir}/startup.bash"

  if ! test -f "${STARTUP_SCRIPT}"; then
    git clone \
      --recurse-submodules \
      --tags \
      "${url}" \
      "${temp_dir}"
  fi
}

function set_up_pass
{
  sudo apt-get install --yes \
    pass

  pass init "wkaluza@protonmail.com"
}

function main
{
  ensure_not_sudo

  prepare_apt
  prepare_gnupg
  prepare_umask_and_home_permissions

  clone_personal_tools

  set_up_pass

  bash "${THIS_SCRIPT_DIR}/install_docker.bash"
  bash "${THIS_SCRIPT_DIR}/configure_docker.bash"

  bash "${STARTUP_SCRIPT}"
}

main
