set -euo pipefail
shopt -s inherit_errexit

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

  pushd "${dir_path}"
  git fetch --all --recurse-submodules --tags --force
  popd
}

function repo_is_clean
{
  local repo_state="clean"

  git add . >/dev/null

  if ! git diff --cached; then
    repo_state="dirty"
  fi

  git reset --mixed "HEAD" >/dev/null

  if [[ "${repo_state}" == "dirty" ]]; then
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
    git checkout \
      --force \
      "${branch_name}" >/dev/null
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

    clean_repo
  else
    echo "Repository is not clean, aborting"
    exit 1
  fi
}
