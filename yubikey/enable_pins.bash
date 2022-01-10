#!/usr/bin/env bash

set -euo pipefail

THIS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

source "${THIS_SCRIPT_DIR}/../shell_script_imports/logging.bash"
source "${THIS_SCRIPT_DIR}/../shell_script_imports/common.bash"

function set_app_security
{
  print_trace

  local pin="$1"
  local admin_pin="$2"
  local piv_puk_openpgp_reset_code="$3"
  local piv_mgmt_key="$4"
  local public_key_file="$5"

  local default_pin="123456"
  local default_puk="12345678"
  local default_mgmt_key="010203040506070801020304050607080102030405060708"

  log_info "Set FIDO PIN"
  ykman fido access change-pin --new-pin "${pin}"
  sleep 2

  log_info "Set OATH PIN"
  ykman oath access change --clear
  sleep 2
  ykman oath access change --new-password "${pin}"
  sleep 2

  log_info "Set PIV PIN"
  ykman piv access change-pin \
    --new-pin "${pin}" \
    --pin "${default_pin}"
  sleep 2

  log_info "Set PIV PUK"
  ykman piv access change-puk \
    --new-puk "${piv_puk_openpgp_reset_code}" \
    --puk "${default_puk}"
  sleep 2

  log_info "Set PIV management key"
  ykman piv access change-management-key \
    --new-management-key "${piv_mgmt_key}" \
    --management-key "${default_mgmt_key}"
  sleep 2

  local edit_card_passwd_commands="${THIS_SCRIPT_DIR}/config/gpg_edit_card_passwd_commands"

  local now
  now="$(date --utc +'%Y%m%d%H%M%S')"

  local temp_gpg_homedir="${THIS_SCRIPT_DIR}/.gnupg_deleteme___${now}"
  set_up_new_gpg_homedir "${temp_gpg_homedir}"

  gpg --homedir "${temp_gpg_homedir}" --import "${public_key_file}"
  sleep 2

  gpg --homedir "${temp_gpg_homedir}" --card-status
  sleep 2

  log_info "Set PGP PINs"
  gpg \
    --homedir "${temp_gpg_homedir}" \
    --expert \
    --command-file "${edit_card_passwd_commands}" \
    --edit-card
  sleep 2

  rm -rf "${temp_gpg_homedir}"

  gpg --import "${public_key_file}"
  sleep 2
}

function main
{
  local pin="$1"
  local admin_pin="$2"
  local piv_puk_openpgp_reset_code="$3"
  local piv_mgmt_key="$4"
  local public_key_file="$5"

  set_app_security \
    "${pin}" \
    "${admin_pin}" \
    "${piv_puk_openpgp_reset_code}" \
    "${piv_mgmt_key}" \
    "${public_key_file}"
}

# Entry point
main "$1" "$2" "$3" "$4" "$5"
