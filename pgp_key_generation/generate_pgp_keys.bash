set -euo pipefail
if command -v shopt &>/dev/null; then
  shopt -s inherit_errexit
fi
THIS_SCRIPT_DIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"
cd "${THIS_SCRIPT_DIR}"

source "${THIS_SCRIPT_DIR}/../shell_script_imports/preamble.bash"

function perform_exports
{
  print_trace

  local email="$1"
  local public_key_path="$2"
  local public_ssh_key_path="$3"
  local private_key_path="$4"
  local private_subkeys_path="$5"
  local revocation_certificates_dir_path="$6"
  local revocation_certificate_config="$7"
  local ownertrust_path="$8"
  local temp_gpg_homedir="$9"

  gpg \
    --homedir "${temp_gpg_homedir}" \
    --armor \
    --output "${public_key_path}" \
    --export "${email}"
  sleep 2
  gpg \
    --homedir "${temp_gpg_homedir}" \
    --armor \
    --output "${public_ssh_key_path}" \
    --export-ssh-key "${email}"
  sleep 2
  gpg \
    --homedir "${temp_gpg_homedir}" \
    --armor \
    --output "${private_key_path}" \
    --export-secret-keys "${email}"
  sleep 2
  gpg \
    --homedir "${temp_gpg_homedir}" \
    --armor \
    --output "${private_subkeys_path}" \
    --export-secret-subkeys "${email}"
  sleep 2
  gpg \
    --homedir "${temp_gpg_homedir}" \
    --armor \
    --output "${revocation_certificates_dir_path}/unspecified.secret" \
    --command-file "${revocation_certificate_config}_unspecified" \
    --generate-revocation "${email}"
  sleep 2
  gpg \
    --homedir "${temp_gpg_homedir}" \
    --armor \
    --output "${revocation_certificates_dir_path}/compromised.secret" \
    --command-file "${revocation_certificate_config}_compromised" \
    --generate-revocation "${email}"
  sleep 2
  gpg \
    --homedir "${temp_gpg_homedir}" \
    --armor \
    --output "${revocation_certificates_dir_path}/superseded.secret" \
    --command-file "${revocation_certificate_config}_superseded" \
    --generate-revocation "${email}"
  sleep 2
  gpg \
    --homedir "${temp_gpg_homedir}" \
    --armor \
    --output "${revocation_certificates_dir_path}/unused.secret" \
    --command-file "${revocation_certificate_config}_unused" \
    --generate-revocation "${email}"
  sleep 2
  gpg \
    --homedir "${temp_gpg_homedir}" \
    --armor \
    --export-ownertrust >"${ownertrust_path}"
  sleep 2
}

function generate_keys
{
  print_trace

  local email="$1"
  local primary_key_config="$2"
  local config_dir="$3"
  local temp_gpg_homedir="$4"

  # Sleeps are to let rngd build up new entropy
  gpg \
    --homedir "${temp_gpg_homedir}" \
    --expert \
    --full-generate-key \
    --batch "${primary_key_config}"
  sleep 2
  gpg \
    --homedir "${temp_gpg_homedir}" \
    --expert \
    --command-file "${config_dir}/subkey_config_sign" \
    --edit-key "${email}"
  sleep 2
  gpg \
    --homedir "${temp_gpg_homedir}" \
    --expert \
    --command-file "${config_dir}/subkey_config_encrypt" \
    --edit-key "${email}"
  sleep 2
  gpg \
    --homedir "${temp_gpg_homedir}" \
    --expert \
    --command-file "${config_dir}/subkey_config_authenticate" \
    --edit-key "${email}"
  sleep 2
}

function generate_configs
{
  print_trace

  local name="$1"
  local email="$2"
  local key_comment="$3"
  local config_dir="$4"
  local primary_key_config="$5"
  local revocation_certificate_config="$6"

  local primary_key_config_template="${config_dir}/primary_key_config_template"
  local revocation_certificate_config_template="${config_dir}/revocation_certificate_config_template"

  name="${name}" \
    email="${email}" \
    comment="${key_comment}" \
    envsubst <"${primary_key_config_template}" >"${primary_key_config}"
  reason=0 \
    comment="${key_comment}" \
    envsubst <"${revocation_certificate_config_template}" >"${revocation_certificate_config}_unspecified"
  reason=1 \
    comment="${key_comment}" \
    envsubst <"${revocation_certificate_config_template}" >"${revocation_certificate_config}_compromised"
  reason=2 \
    comment="${key_comment}" \
    envsubst <"${revocation_certificate_config_template}" >"${revocation_certificate_config}_superseded"
  reason=3 \
    comment="${key_comment}" \
    envsubst <"${revocation_certificate_config_template}" >"${revocation_certificate_config}_unused"
}

function main
{
  local key_purpose="$1"

  local name="Wojciech Kaluza"
  local email="wkaluza@protonmail.com"

  local now
  now="$(date --utc +'%Y%m%d%H%M%S')"
  local prefix="${key_purpose}_${now}"
  local key_comment="${prefix}"

  local temp_gpg_homedir="${THIS_SCRIPT_DIR}/.gnupg_deleteme___${prefix}"
  set_up_new_gpg_homedir "${temp_gpg_homedir}"

  local config_dir="${THIS_SCRIPT_DIR}/config"

  local temp_dir="${THIS_SCRIPT_DIR}/${prefix}_temp___"
  local secrets_output_dir="${THIS_SCRIPT_DIR}/${prefix}_secrets___"

  mkdir "${temp_dir}"
  mkdir "${secrets_output_dir}"

  local primary_key_config="${temp_dir}/primary_key_config"
  local revocation_certificate_config="${temp_dir}/revocation_certificate_config"
  generate_configs \
    "${name}" \
    "${email}" \
    "${key_comment}" \
    "${config_dir}" \
    "${primary_key_config}" \
    "${revocation_certificate_config}"

  generate_keys \
    "${email}" \
    "${primary_key_config}" \
    "${config_dir}" \
    "${temp_gpg_homedir}"

  local public_key_path="${secrets_output_dir}/${prefix}_pgp_key.pub"
  local public_ssh_key_path="${secrets_output_dir}/${prefix}_ssh_from_pgp_key.pub"
  local private_key_path="${secrets_output_dir}/${prefix}_pgp_key.secret"
  local private_subkeys_path="${secrets_output_dir}/${prefix}_pgp_subkeys.secret"
  local revocation_certificates_dir_path="${secrets_output_dir}/${prefix}_pgp_revocation_certificates"
  local ownertrust_path="${secrets_output_dir}/${prefix}_pgp_ownertrust.pub"

  mkdir "${revocation_certificates_dir_path}"

  perform_exports \
    "${email}" \
    "${public_key_path}" \
    "${public_ssh_key_path}" \
    "${private_key_path}" \
    "${private_subkeys_path}" \
    "${revocation_certificates_dir_path}" \
    "${revocation_certificate_config}" \
    "${ownertrust_path}" \
    "${temp_gpg_homedir}"

  rm -rf "${temp_gpg_homedir}"

  gpg --import "${public_key_path}"
  sleep 2
  gpg --import-ownertrust "${ownertrust_path}"
  sleep 2

  echo ""
  echo "*** gpg --list-keys ************************************************************"
  gpg --list-keys
  sleep 2

  echo "*** gpg --list-secret-keys *****************************************************"
  gpg --list-secret-keys
  sleep 2

  echo "*** gpg --check-signatures *****************************************************"
  gpg --check-signatures
  sleep 2

  echo "********************************************************************************"

  log_info "Keys and revocation certificates exported to ${secrets_output_dir}"
}

main "$1"
