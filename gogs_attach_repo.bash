set -euo pipefail
if command -v shopt &>/dev/null; then
  shopt -s inherit_errexit
fi
THIS_SCRIPT_DIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"
cd "${THIS_SCRIPT_DIR}"

source "${THIS_SCRIPT_DIR}/shell_script_imports/preamble.bash"

REMOTE_NAME="gogs"
GOGS_USERNAME="wkaluza"

function add_git_remote
{
  local repo_name="$1"

  git remote add \
    "${REMOTE_NAME}" \
    "git@${DOMAIN_GIT_FRONTEND_df29c969}:${GOGS_USERNAME}/${repo_name}.git"
}

function perform_fetch
{
  git fetch \
    --all \
    --force \
    --recurse-submodules \
    --tags
}

function perform_push
{
  git push \
    --all \
    --force \
    --repo "${REMOTE_NAME}" \
    --set-upstream

  git push \
    --force \
    --repo "${REMOTE_NAME}" \
    --tags
}

function main
{
  local current_repo_directory
  current_repo_directory="$(realpath "$1")"

  pushd "${current_repo_directory}" >/dev/null

  local repo_name
  repo_name="$(basename "${current_repo_directory}")"

  add_git_remote \
    "${repo_name}" >/dev/null 2>&1 ||
    true

  local description="placeholder description"

  local token
  token="$(pass show "local_gogs_token_${GOGS_USERNAME}")"
  local auth_header="Authorization: token ${token}"

  if ! gogs_check_repo_exists \
    "${DOMAIN_GIT_FRONTEND_df29c969}" \
    "${GOGS_USERNAME}" \
    "${repo_name}" \
    "${auth_header}"; then
    log_info "Creating gogs repository..."
    gogs_create_repo \
      "${DOMAIN_GIT_FRONTEND_df29c969}" \
      "${GOGS_USERNAME}" \
      "${repo_name}" \
      "${description}" \
      "${auth_header}" >/dev/null 2>&1
  fi

  if ! gogs_list_webhooks \
    "${DOMAIN_GIT_FRONTEND_df29c969}" \
    "${GOGS_USERNAME}" \
    "${auth_header}" \
    "${repo_name}" |
    jq 'if . | length > 0 then . else error("No webhooks found") end' - >/dev/null 2>&1; then
    log_info "Adding webhook..."
    gogs_create_webhook \
      "${DOMAIN_GIT_FRONTEND_df29c969}" \
      "https://${DOMAIN_WEBHOOK_SINK_a8800f5b}/gogs" \
      "${GOGS_USERNAME}" \
      "$(pass_show_or_generate "local_gogs_webhook_secret")" \
      "${auth_header}" \
      "${repo_name}" >/dev/null
  fi

  log_info "Fetching..."
  perform_fetch >/dev/null 2>&1

  log_info "Pushing branches and tags..."
  perform_push >/dev/null 2>&1

  popd >/dev/null

  log_info "Success: $(basename "$0")"
}

main "$1"
