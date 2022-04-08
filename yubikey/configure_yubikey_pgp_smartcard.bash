set -euo pipefail
shopt -s inherit_errexit

THIS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

source "${THIS_SCRIPT_DIR}/../shell_script_imports/logging.bash"
source "${THIS_SCRIPT_DIR}/../shell_script_imports/common.bash"

function configure_openpgp_card_metadata
{
  print_trace

  local first_name="$1"
  local last_name="$2"
  local primary_key_fingerprint="$3"
  local temp_gpg_homedir="$4"
  local now="$5"

  local public_key_url="https://keys.openpgp.org/vks/v1/by-fingerprint/${primary_key_fingerprint}"

  local edit_card_metadata_commands_template="${THIS_SCRIPT_DIR}/config/gpg_edit_card_metadata_commands_template"
  local edit_card_metadata_commands="${THIS_SCRIPT_DIR}/config/gpg_edit_card_metadata_commands___${now}"

  local kdf_setup_command
  if gpg --homedir "${temp_gpg_homedir}" --card-status | grep "^KDF setting" >/dev/null; then
    log_info "OpenPGP smartcard: KDF is supported"
    kdf_setup_command="kdf-setup"
  else
    log_info "OpenPGP smartcard: KDF is not supported"
    kdf_setup_command=""
  fi

  kdf_setup_command="${kdf_setup_command}" \
    public_key_url="${public_key_url}" \
    last_name="${last_name}" \
    first_name="${first_name}" \
    envsubst <"${edit_card_metadata_commands_template}" >"${edit_card_metadata_commands}"

  gpg \
    --homedir "${temp_gpg_homedir}" \
    --expert \
    --command-file "${edit_card_metadata_commands}" \
    --edit-card
  sleep 2
}

function upload_pgp_keys
{
  print_trace

  local primary_key_fingerprint="$1"
  local signing_key_fingerprint="$2"
  local encryption_key_fingerprint="$3"
  local authentication_key_fingerprint="$4"
  local temp_gpg_homedir="$5"
  local now="$6"

  local keytocard_commands_template="${THIS_SCRIPT_DIR}/config/gpg_keytocard_commands_template"
  local keytocard_commands="${THIS_SCRIPT_DIR}/config/gpg_keytocard_commands___${now}"

  signing_key_fingerprint="${signing_key_fingerprint}" \
    encryption_key_fingerprint="${encryption_key_fingerprint}" \
    authentication_key_fingerprint="${authentication_key_fingerprint}" \
    envsubst <"${keytocard_commands_template}" >"${keytocard_commands}"

  gpg \
    --homedir "${temp_gpg_homedir}" \
    --expert \
    --command-file "${keytocard_commands}" \
    --edit-key "${primary_key_fingerprint}"
  sleep 2
}

function upload_secrets_and_config
{
  print_trace

  local first_name="$1"
  local last_name="$2"
  local primary_key_fingerprint="$3"
  local signing_key_fingerprint="$4"
  local encryption_key_fingerprint="$5"
  local authentication_key_fingerprint="$6"
  local temp_gpg_homedir="$7"
  local now="$8"

  gpg \
    --homedir "${temp_gpg_homedir}" \
    --card-status
  sleep 2

  configure_openpgp_card_metadata \
    "${first_name}" \
    "${last_name}" \
    "${primary_key_fingerprint}" \
    "${temp_gpg_homedir}" \
    "${now}"

  upload_pgp_keys \
    "${primary_key_fingerprint}" \
    "${signing_key_fingerprint}" \
    "${encryption_key_fingerprint}" \
    "${authentication_key_fingerprint}" \
    "${temp_gpg_homedir}" \
    "${now}"
}

function main
{
  local primary_key_fingerprint="$1"
  local signing_key_fingerprint="$2"
  local encryption_key_fingerprint="$3"
  local authentication_key_fingerprint="$4"
  local secret_subkeys_file="$5"
  local public_key_file="$6"

  local first_name="Wojciech"
  local last_name="Kaluza"
  local now
  now="$(date --utc +'%Y%m%d%H%M%S')"

  local temp_gpg_homedir="${THIS_SCRIPT_DIR}/.gnupg_deleteme___${now}"
  set_up_new_gpg_homedir "${temp_gpg_homedir}"

  gpg --import "${public_key_file}"
  sleep 2
  gpg --homedir "${temp_gpg_homedir}" --import "${public_key_file}"
  sleep 2
  gpg --homedir "${temp_gpg_homedir}" --import "${secret_subkeys_file}"
  sleep 2

  upload_secrets_and_config \
    "${first_name}" \
    "${last_name}" \
    "${primary_key_fingerprint}" \
    "${signing_key_fingerprint}" \
    "${encryption_key_fingerprint}" \
    "${authentication_key_fingerprint}" \
    "${temp_gpg_homedir}" \
    "${now}"

  rm -rf "${temp_gpg_homedir}"
}

# Entry point
main "$1" "$2" "$3" "$4" "$5" "$6"
