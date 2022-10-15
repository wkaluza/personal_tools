set -euo pipefail
if command -v shopt &>/dev/null; then
  shopt -s inherit_errexit
fi

function run_in_context
{
  local dir_path
  dir_path="$(realpath "$1")"
  local fn_arg="$2"

  mkdir --parents "${dir_path}"

  pushd "${dir_path}" >/dev/null
  ${fn_arg} "${@:3}"
  popd >/dev/null
}

function untar_gzip_to
{
  local archive
  archive="$(realpath "$1")"
  local target_dir
  target_dir="$(realpath "$2")"

  mkdir --parents "${target_dir}"

  tar \
    --directory "${target_dir}" \
    --extract \
    --file "${archive}" \
    --gzip
}
