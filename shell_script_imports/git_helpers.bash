set -euo pipefail

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
      --recurse-submodules \
      "${url}" \
      "${dir_path}"
  fi

  pushd "${dir_path}"
  git fetch --all --recurse-submodules --tags
  popd
}
