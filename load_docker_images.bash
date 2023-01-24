set -euo pipefail
if command -v shopt &>/dev/null; then
  shopt -s inherit_errexit
fi
THIS_SCRIPT_DIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"

source "${THIS_SCRIPT_DIR}/shell_script_imports/preamble.bash"

function tag_image
{
  local json="$1"

  local id
  id="$(echo "${json}" |
    jq --raw-output '.id' -)"
  local repo
  repo="$(echo "${json}" |
    jq --raw-output '.repository' -)"
  local tag
  tag="$(echo "${json}" |
    jq --raw-output '.tag' -)"

  log_info "Tagging ${id} as ${repo}:${tag}..."
  docker tag "${id}" "${repo}:${tag}"
}

function tag_loaded_images
{
  local input_dir="$1"

  local input="${input_dir}/docker_image_data.txt"

  cat "${input}" |
    jq --compact-output '.[]' - |
    for_each tag_image
}

function load_images
{
  local input_dir="$1"

  find "${input_dir}" \
    -type f \
    -iname '*.tar' \
    -exec docker load --quiet --input {} \;
}

function main
{
  local input_dir="$1"

  load_images \
    "${input_dir}"
  tag_loaded_images \
    "${input_dir}"

  log_info "Success $(basename "$0")"
}

main "$1"
