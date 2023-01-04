set -euo pipefail
if command -v shopt &>/dev/null; then
  shopt -s inherit_errexit
fi

function clean_repo
{
  git clean -dffx
  git checkout .

  git submodule foreach --recursive git clean -dffx
  git submodule foreach --recursive git checkout .
}

function check_out
{
  local commit="$1"

  local current_sha
  current_sha="$(git rev-parse HEAD)"
  local target_sha
  target_sha="$(git rev-parse "${commit}")"

  if [[ "${current_sha}" != "${target_sha}" ]]; then
    git checkout --force "${commit}"
    git submodule update --recursive
    clean_repo
  fi
}

function clone_or_fetch
{
  local url="$1"
  local dir_path="$2"

  if ! test -d "${dir_path}"; then
    git clone \
      --tags \
      --recurse-submodules \
      "${url}" \
      "${dir_path}"
  fi

  quiet pushd "${dir_path}"
  git fetch \
    --all \
    --force \
    --recurse-submodules \
    --tags

  git verify-commit HEAD
  quiet popd
}

function is_git_repo
{
  if quiet git status --short; then
    true
  else
    false
  fi
}

function repo_is_clean
{
  if ! is_git_repo; then
    log_error "Not a git repo (pwd ${pwd})"
    exit 1
  fi

  if [[ "$(git status --short | wc -l)" == "0" ]]; then
    true
  else
    false
  fi
}

function clean_repo
{
  quiet git add .
  quiet git reset --hard "HEAD"
  quiet git clean -dffx
}

function git_get_latest
{
  local remote_name="${1:-"origin"}"
  local branch_name="${2:-"main"}"

  if repo_is_clean; then
    git verify-commit HEAD

    quiet git checkout \
      --force \
      "${branch_name}" ||
      quiet git checkout \
        --force \
        --track "${remote_name}/${branch_name}"

    git verify-commit HEAD

    quiet git fetch \
      --all \
      --force \
      --prune \
      --recurse-submodules \
      --tags
    quiet git reset \
      --hard \
      "${remote_name}/${branch_name}"

    git verify-commit HEAD

    clean_repo
  else
    log_error "Repository is not clean, aborting"
    exit 1
  fi
}
