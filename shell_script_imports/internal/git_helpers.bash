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

  pushd "${dir_path}" >/dev/null
  git fetch \
    --all \
    --force \
    --recurse-submodules \
    --tags

  git verify-commit HEAD
  popd >/dev/null
}

function is_git_repo
{
  if git status --short >/dev/null 2>&1; then
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
  git add . >/dev/null
  git reset --hard "HEAD" >/dev/null
  git clean -dffx >/dev/null
}

function git_get_latest
{
  local remote_name="${1:-"origin"}"
  local branch_name="${2:-"main"}"

  if repo_is_clean; then
    git verify-commit HEAD

    git checkout \
      --force \
      "${branch_name}" >/dev/null 2>&1 ||
      git checkout \
        --force \
        --track "${remote_name}/${branch_name}" >/dev/null 2>&1

    git verify-commit HEAD

    git fetch \
      --all \
      --force \
      --prune \
      --prune-tags \
      --recurse-submodules \
      --tags >/dev/null
    git reset \
      --hard \
      "${remote_name}/${branch_name}" >/dev/null

    git verify-commit HEAD

    clean_repo
  else
    log_error "Repository is not clean, aborting"
    exit 1
  fi
}
