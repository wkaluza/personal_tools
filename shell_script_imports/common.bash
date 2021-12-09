#!/usr/bin/env bash

set -euo pipefail

function ensure_not_sudo {
  if test "0" -eq "$(id -u)"; then
    echo "Do not run this as root"
    exit 1
  fi
}

function run_in_context {
  local dir_path
  dir_path="$(realpath "$1")"
  local fn_arg="$2"

  mkdir --parents "${dir_path}"
  pushd "${dir_path}"
  $fn_arg "${@:3}"
  popd
}

function set_up_new_gpg_homedir {
  local temp_gpg_homedir="$1"

  mkdir "${temp_gpg_homedir}"
  chmod u+rwx,go-rwx "${temp_gpg_homedir}"

  if test -z "${GNUPGHOME+a}"; then
    cp "$HOME/.gnupg/gpg.conf" "${temp_gpg_homedir}"
  else
    cp "$GNUPGHOME/gpg.conf" "${temp_gpg_homedir}"
  fi

  gpgconf --kill gpg-agent
  sleep 2
  gpgconf --kill scdaemon
  sleep 2

  gpg --list-keys >/dev/null
  sleep 2
  gpg --list-secret-keys >/dev/null
  sleep 2

  gpg --homedir "${temp_gpg_homedir}" --list-keys >/dev/null
  sleep 2
  gpg --homedir "${temp_gpg_homedir}" --list-secret-keys >/dev/null
  sleep 2
}
