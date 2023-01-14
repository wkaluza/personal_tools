set -euo pipefail
if command -v shopt &>/dev/null; then
  shopt -s inherit_errexit
fi
THIS_SCRIPT_DIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"
cd "${THIS_SCRIPT_DIR}"

source "${THIS_SCRIPT_DIR}/shell_script_imports/preamble.bash"

function wrap_as_json
{
  local json="$1"

  echo "${json}" |
    jq \
      --compact-output \
      --sort-keys \
      '. | {id: .ID, repository: .Repository, tag: .Tag}' -
}

function get_tags_for_id
{
  local id="$1"

  docker image ls \
    --format '{{ json . }}' |
    jq \
      --compact-output \
      ". | select(.ID == \"${id}\")" - |
    for_each wrap_as_json
}

function save_image_tags
{
  local output_dir="$1"

  local output="${output_dir}/docker_image_data.txt"

  touch "${output}"

  get_short_image_ids |
    for_each get_tags_for_id |
    jq \
      --slurp \
      --sort-keys \
      '.' - >>"${output}"
}

function save_images
{
  local output_dir="$1"

  get_short_image_ids |
    while read -r id; do
      log_info "Saving image ${id}..."

      docker save \
        --output "${output_dir}/${id}.tar" \
        ${id}
    done
}

function main
{
  local now
  now="$(date --utc +'%Y%m%d%H%M%S%N')"
  local output_dir="${THIS_SCRIPT_DIR}/docker_images_backup_${now}___"

  rm -rf "${output_dir}"
  mkdir --parents "${output_dir}"

  save_images \
    "${output_dir}"
  save_image_tags \
    "${output_dir}"

  log_info "Success $(basename "$0")"
}

main
