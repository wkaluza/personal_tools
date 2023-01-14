set -euo pipefail
if command -v shopt &>/dev/null; then
  shopt -s inherit_errexit
fi
THIS_SCRIPT_DIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"
cd "${THIS_SCRIPT_DIR}"

source "${THIS_SCRIPT_DIR}/shell_script_imports/preamble.bash"

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

  gpg \
    --export-ssh-key "${primary_key_fingerprint}" |
    pass_store_if_absent \
      "${PASS_SECRET_ID_PERSONAL_SSH_PUBLIC_KEY_ts5geji6}"

  log_info "Success $(basename "$0")"
}

main
