set -euo pipefail

function run_in_context
{
  local dir_path
  dir_path="$(realpath "$1")"
  local fn_arg="$2"

  mkdir --parents "${dir_path}"

  pushd "${dir_path}"
  $fn_arg "${@:3}"
  popd
}

function untar_gzip_to
{
  local archive
  archive="$(realpath "$1")"
  local target_dir
  target_dir="$(realpath "$2")"

  mkdir --parents "${target_dir}"

  mv "${archive}" "${target_dir}"

  pushd "${target_dir}"
  tar -xzf "${target_dir}/${archive}"
  rm "${target_dir}/${archive}"
  popd
}
