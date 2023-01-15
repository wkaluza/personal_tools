set -euo pipefail
if command -v shopt &>/dev/null; then
  shopt -s inherit_errexit
fi
THIS_SCRIPT_DIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"
cd "${THIS_SCRIPT_DIR}"

source "${THIS_SCRIPT_DIR}/shell_script_imports/preamble.bash"

GIT_FRONTEND_STACK_NAME="local_git_frontend_stack"

function sync_github_to_gogs_if_newer
{
  local username="$1"
  local repo_name="$2"

  local temp_dir
  temp_dir="$(mktemp -d)/repo"

  local github_url="ssh://git@github.com/${username}/${repo_name}.git"
  local gogs_url="ssh://git@${DOMAIN_GIT_FRONTEND_df29c969}/${username}/${repo_name}.git"

  local default_remote="origin"
  local github_remote="github"
  local gogs_remote="gogs"
  local branch="main"

  quiet clone_or_fetch \
    "${github_url}" \
    "${temp_dir}"

  quiet pushd "${temp_dir}"

  if ! git remote | quiet grep -E "^${github_remote}$"; then
    git remote rename \
      "${default_remote}" \
      "${github_remote}"
  fi

  if ! git remote | quiet grep -E "^${gogs_remote}$"; then
    git remote add \
      "${gogs_remote}" \
      "${gogs_url}"
  fi

  quiet git_get_latest \
    "${github_remote}" \
    "${branch}"

  local github_main
  github_main="$(git rev-parse "${github_remote}/${branch}")"

  if quiet git rev-parse "${gogs_remote}/${branch}"; then
    local gogs_main
    gogs_main="$(git rev-parse "${gogs_remote}/${branch}")"

    if git merge-base \
      --is-ancestor "${gogs_main}" \
      "${github_main}"; then
      quiet git push \
        "${gogs_remote}" \
        "${branch}"
    else
      quiet git_get_latest \
        "${gogs_remote}" \
        "${branch}"
    fi
  else
    quiet git push \
      "${gogs_remote}" \
      "${branch}"
  fi

  quiet popd

  rm -rf "${temp_dir}"
}

function ensure_gogs_repo_exists
{
  local username="$1"
  local repo_name="$2"

  local repo_description="${repo_name}"
  local token
  token="$(pass_show \
    "${PASS_SECRET_ID_GOGS_ACCESS_TOKEN_t6xznusu}")"
  local auth_header="Authorization: token ${token}"

  if ! gogs_check_repo_exists \
    "${DOMAIN_GIT_FRONTEND_df29c969}" \
    "${username}" \
    "${repo_name}" \
    "${auth_header}"; then
    log_info "Creating gogs repository ${repo_name}..."
    quiet gogs_create_repo \
      "${DOMAIN_GIT_FRONTEND_df29c969}" \
      "${username}" \
      "${repo_name}" \
      "${repo_description}" \
      "${auth_header}"
    quiet sync_github_to_gogs_if_newer \
      "${username}" \
      "${repo_name}"
  fi
}

function upload_ssh_key_if_absent
{
  local username="$1"
  local ssh_key_name="$2"
  local auth_header="$3"
  local public_key="$4"

  if ! quiet gogs_ssh_key_exists \
    "${DOMAIN_GIT_FRONTEND_df29c969}" \
    "${username}" \
    "${ssh_key_name}" \
    "${auth_header}"; then
    log_info "Uploading SSH key ${ssh_key_name} to gogs..."
    gogs_create_ssh_key \
      "${DOMAIN_GIT_FRONTEND_df29c969}" \
      "${ssh_key_name}" \
      "${public_key}" \
      "${auth_header}"
  else
    log_info "Gogs SSH key ${ssh_key_name} already uploaded"
  fi
}

function ensure_gogs_user_configured
{
  local username="$1"

  local gogs_token_name="access_token_${username}"
  local pass_gogs_token_id="${PASS_SECRET_ID_GOGS_ACCESS_TOKEN_t6xznusu}"

  local password
  password="$(pass_show \
    "${PASS_SECRET_ID_GOGS_USER_PASSWORD_hezqdg53}")"

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
    quiet grep -E "^${gogs_token_name}$"; then
    log_info "Gogs token exists"
  else
    log_info "Creating gogs token..."

    gogs_generate_token \
      "${DOMAIN_GIT_FRONTEND_df29c969}" \
      "${username}" \
      "${password}" \
      "${gogs_token_name}" |
      pass_store "${pass_gogs_token_id}"
  fi

  local token_value
  token_value="$(pass_show "${pass_gogs_token_id}")"
  local auth_header="Authorization: token ${token_value}"

  upload_ssh_key_if_absent \
    "${username}" \
    "gogs_personal_ssh_key_${username}" \
    "${auth_header}" \
    "$(pass_show "${PASS_SECRET_ID_PERSONAL_SSH_PUBLIC_KEY_ts5geji6}")"
  upload_ssh_key_if_absent \
    "${username}" \
    "gogs_gitops_ssh_key_admin" \
    "${auth_header}" \
    "$(pass_show \
      "${PASS_SECRET_ID_GITOPS_SSH_PUBLIC_KEY_ADMIN_rclub6oc}")"
}

function create_main_repos
{
  local username="$1"

  ensure_gogs_repo_exists \
    "${username}" \
    "personal_tools"
  ensure_gogs_repo_exists \
    "${username}" \
    "infrastructure"
  ensure_gogs_repo_exists \
    "${username}" \
    "sandbox"
}

function main
{
  local username="wkaluza"

  ensure_gogs_user_configured \
    "${username}"

  create_main_repos \
    "${username}"

  log_info "Success $(basename "$0")"
}

main
