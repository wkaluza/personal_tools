set -euo pipefail
if command -v shopt &>/dev/null; then
  shopt -s inherit_errexit
fi
THIS_SCRIPT_DIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"
cd "${THIS_SCRIPT_DIR}"

source "${THIS_SCRIPT_DIR}/shell_script_imports/preamble.bash"

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

  quiet clone_or_fetch \
    "ssh://git@github.com/${username}/${repo_name}.git" \
    "${infra_dir}"

  quiet pushd "${infra_dir}"
  if ! git remote | quiet grep -E "^${github_remote}$"; then
    git remote rename \
      "${default_remote}" \
      "${github_remote}"
  fi

  if ! git remote | quiet grep -E "^${gogs_remote}$"; then
    git remote add \
      "${gogs_remote}" \
      "ssh://git@${DOMAIN_GIT_FRONTEND_df29c969}/${username}/${repo_name}.git"
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

  prepare_local_infrastructure_clone \
    "${username}" \
    "${repo_name}" \
    "${infra_dir}"
  bootstrap_infrastructure \
    "${infra_dir}"

  log_info "Success $(basename "$0")"
}

main
