set -euo pipefail
if command -v shopt &>/dev/null; then
  shopt -s inherit_errexit
fi
THIS_SCRIPT_DIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"
cd "${THIS_SCRIPT_DIR}"

source "${THIS_SCRIPT_DIR}/shell_script_imports/preamble.bash"

GIT_FRONTEND_STACK_NAME="local_git_frontend_stack"

function ensure_gogs_user_configured
{
  local username="$1"

  local pass_gogs_password_id="local_gogs_password_${username}"
  local token_name="local_gogs_token_${username}"
  local pass_gogs_token_id="${token_name}"
  local ssh_key_name="ssh_key_${username}"

  local password
  password="$(pass_show_or_generate "${pass_gogs_password_id}")"

  local primary_key_fingerprint="174C9368811039C87F0C806A896572D1E78ED6A7"

  if quiet gogs_get_single_user \
    "${DOMAIN_GIT_FRONTEND_df29c969}" \
    "${username}"; then
    log_info "Gogs user ${username} exists"
  else
    log_info "Creating gogs user ${username}..."

    quiet gogs_docker_cli_create_admin_user \
      "${GIT_FRONTEND_STACK_NAME}" \
      "/app/gogs/gogs" \
      "wkaluza@protonmail.com" \
      "${username}" \
      "${password}"
  fi

  if gogs_list_token_names \
    "${DOMAIN_GIT_FRONTEND_df29c969}" \
    "${username}" \
    "${password}" |
    quiet grep -E "^${token_name}$"; then
    log_info "Gogs token exists"
  else
    log_info "Creating gogs token..."

    gogs_generate_token \
      "${DOMAIN_GIT_FRONTEND_df29c969}" \
      "${username}" \
      "${password}" \
      "${token_name}" |
      store_in_pass "${pass_gogs_token_id}"
  fi

  local token_value
  token_value="$(pass show "${pass_gogs_token_id}")"
  local auth_header="Authorization: token ${token_value}"

  if ! quiet gogs_ssh_key_exists \
    "${DOMAIN_GIT_FRONTEND_df29c969}" \
    "${username}" \
    "${ssh_key_name}" \
    "${auth_header}"; then
    log_info "Uploading SSH key to gogs..."
    gogs_create_ssh_key \
      "${DOMAIN_GIT_FRONTEND_df29c969}" \
      "${ssh_key_name}" \
      "$(gpg --export-ssh-key "${primary_key_fingerprint}")" \
      "${auth_header}"
  else
    log_info "Gogs SSH key already uploaded"
  fi
}

function main
{
  local username="wkaluza"

  ensure_gogs_user_configured \
    "${username}"

  log_info "Success $(basename "$0")"
}

main
