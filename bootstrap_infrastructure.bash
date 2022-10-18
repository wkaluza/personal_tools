set -euo pipefail
if command -v shopt &>/dev/null; then
  shopt -s inherit_errexit
fi
THIS_SCRIPT_DIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"
cd "${THIS_SCRIPT_DIR}"

source "${THIS_SCRIPT_DIR}/shell_script_imports/preamble.bash"

function ensure_gogs_repo_exists
{
  local username="$1"
  local repo_name="$2"

  local repo_description="Personal infrastructure repository"
  local token
  token="$(pass show "local_gogs_token_${username}")"
  local auth_header="Authorization: token ${token}"

  if ! gogs_check_repo_exists \
    "${DOMAIN_GIT_FRONTEND_df29c969}" \
    "${username}" \
    "${repo_name}" \
    "${auth_header}"; then
    log_info "Creating gogs repository ${repo_name}..."
    gogs_create_repo \
      "${DOMAIN_GIT_FRONTEND_df29c969}" \
      "${username}" \
      "${repo_name}" \
      "${repo_description}" \
      "${auth_header}" >/dev/null 2>&1
  fi
}

function prepare_local_infrastructure_clone
{
  local username="$1"
  local repo_name="$2"
  local infra_dir="$3"

  local default_remote="origin"
  local github_remote="github"
  local gogs_remote="gogs"
  local branch="main"

  log_info "Updating local ${repo_name} clone..."

  clone_or_fetch \
    "git@github.com:${username}/${repo_name}.git" \
    "${infra_dir}" >/dev/null 2>&1

  pushd "${infra_dir}" >/dev/null
  if ! git remote | grep -E "^${github_remote}$" >/dev/null; then
    git remote rename \
      "${default_remote}" \
      "${github_remote}"
  fi

  if ! git remote | grep -E "^${gogs_remote}$" >/dev/null; then
    git remote add \
      "${gogs_remote}" \
      "git@${DOMAIN_GIT_FRONTEND_df29c969}:${username}/${repo_name}.git"
  fi

  git_get_latest \
    "${github_remote}" \
    "${branch}" >/dev/null 2>&1

  local github_main
  github_main="$(git rev-parse "${github_remote}/${branch}")"
  local gogs_main
  gogs_main="$(git rev-parse "${gogs_remote}/${branch}")"

  if git merge-base \
    --is-ancestor "${gogs_main}" \
    "${github_main}"; then
    git push \
      "${gogs_remote}" \
      "${branch}" >/dev/null 2>&1
  else
    git_get_latest \
      "${gogs_remote}" \
      "${branch}" >/dev/null 2>&1
  fi

  popd >/dev/null
}

function bootstrap_infrastructure
{
  local infra_dir="$1"

  local bootstrap_script="${infra_dir}/scripts/bootstrap_infrastructure.bash"

  if test -f "${bootstrap_script}"; then
    log_info "Bootstrapping..."
    bash "${bootstrap_script}"
  fi
}

function main
{
  local username="wkaluza"
  local repo_name="infrastructure"

  local infra_dir="${HOME}/.wk_infrastructure___"

  ensure_gogs_repo_exists \
    "${username}" \
    "${repo_name}"
  prepare_local_infrastructure_clone \
    "${username}" \
    "${repo_name}" \
    "${infra_dir}"
  bootstrap_infrastructure \
    "${infra_dir}"

  log_info "Success $(basename "$0")"
}

main
