#!/usr/bin/env bash

set -euo pipefail

function ensure_not_sudo() {
  if test "0" -eq "$(id -u)"; then
    echo "Do not run this as root"
    exit 1
  fi
}

function press_any_key_to_() {
  local action="$1"

  echo "Press any key to ${action} or Ctrl-c to quit"
  read -n 1 -s -r
}

function wait_and_reboot() {
  press_any_key_to_ "reboot"
  sudo reboot
}

function set_up_new_gpg_homedir() {
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
