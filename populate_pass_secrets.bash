set -euo pipefail
if command -v shopt &>/dev/null; then
  shopt -s inherit_errexit
fi
THIS_SCRIPT_DIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"

source "${THIS_SCRIPT_DIR}/shell_script_imports/preamble.bash"

function pass_generate_sealed_secrets_cert_if_absent
{
  local secret_key_id="$1"
  local certificate_id="$2"

  if ! pass_exists "${secret_key_id}" ||
    ! pass_exists "${certificate_id}"; then
    local temp_dir
    temp_dir="$(mktemp -d)"
    local key_path="${temp_dir}/key"
    local cert_path="${temp_dir}/cert"

    quiet openssl req \
      -x509 \
      -nodes \
      -newkey "rsa:4096" \
      -keyout "${key_path}" \
      -out "${cert_path}" \
      -subj "/CN=sealed-secret/O=sealed-secret"

    cat "${key_path}" |
      pass_store "${secret_key_id}"
    cat "${cert_path}" |
      pass_store "${certificate_id}"

    rm -rf "${temp_dir}"
  fi
}

function pass_generate_k8s_user_csr_if_absent
{
  local username="$1"
  local key_id="$2"
  local csr_id="$3"

  if ! pass_exists "${key_id}" ||
    ! pass_exists "${csr_id}"; then
    local temp_dir
    temp_dir="$(mktemp -d)"
    local key_path="${temp_dir}/key"
    local csr_path="${temp_dir}/csr"

    quiet openssl genrsa \
      -out "${key_path}" \
      4096
    quiet openssl req \
      -new \
      -key "${key_path}" \
      -out "${csr_path}" \
      -sha256 \
      -subj "/CN=${username}/O=${username}"

    cat "${key_path}" |
      pass_store "${key_id}"
    cat "${csr_path}" |
      pass_store "${csr_id}"

    rm -rf "${temp_dir}"
  fi
}

function pass_generate_key_pair_if_absent
{
  local secret_key_id="$1"
  local public_key_id="$2"

  if ! pass_exists "${secret_key_id}" ||
    ! pass_exists "${public_key_id}"; then
    local key_pair_json
    key_pair_json="$(generate_rsa4096_key_pair)"

    echo "${key_pair_json}" |
      jq --raw-output '.secret_key' - |
      base64 -d |
      pass_store \
        "${secret_key_id}"

    echo "${key_pair_json}" |
      jq --raw-output '.public_key' - |
      base64 -d |
      pass_store \
        "${public_key_id}"
  fi
}

function main
{
  local primary_key_fingerprint="174C9368811039C87F0C806A896572D1E78ED6A7"

  pass_generate_if_absent \
    "${PASS_SECRET_ID_GOGS_USER_PASSWORD_hezqdg53}"
  pass_generate_if_absent \
    "${PASS_SECRET_ID_GOGS_CONFIG_SECRET_KEY_nelzbcve}"
  pass_generate_if_absent \
    "${PASS_SECRET_ID_GOGS_WEBHOOK_SECRET_8q7aqxbl}"

  pass_generate_key_pair_if_absent \
    "${PASS_SECRET_ID_GITOPS_SSH_SECRET_KEY_ADMIN_duccc5fs}" \
    "${PASS_SECRET_ID_GITOPS_SSH_PUBLIC_KEY_ADMIN_rclub6oc}"

  pass_generate_sealed_secrets_cert_if_absent \
    "${PASS_SECRET_ID_SEALED_SECRETS_KEY_kxlsnqam}" \
    "${PASS_SECRET_ID_SEALED_SECRETS_CERTIFICATE_4edcp3cm}"

  pass_generate_k8s_user_csr_if_absent \
    "wkaluza" \
    "${PASS_SECRET_ID_K8S_USER_KEY_nzgamwny}" \
    "${PASS_SECRET_ID_K8S_USER_CSR_xf7rrqr3}"

  gpg \
    --export-ssh-key "${primary_key_fingerprint}" |
    pass_store_if_absent \
      "${PASS_SECRET_ID_PERSONAL_SSH_PUBLIC_KEY_ts5geji6}"

  log_info "Success $(basename "$0")"
}

main
