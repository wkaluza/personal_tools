set -euo pipefail
if command -v shopt &>/dev/null; then
  shopt -s inherit_errexit
fi
THIS_SCRIPT_DIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"

source "${THIS_SCRIPT_DIR}/shell_script_imports/preamble.bash"

function list_images
{
  local prefix="$1"

  local escaped_host
  escaped_host="$(echo "${DOMAIN_DOCKER_REGISTRY_PRIVATE_a8a1ce1e}" |
    sed -E 's|\.|\\\\\.|g')"
  local regex="^${escaped_host}/${prefix}/.+$"

  docker image ls \
    --all \
    --digests \
    --format '{{ json . }}' \
    --no-trunc |
    jq ". | select (.Repository | test(\"${regex}\"))" - |
    jq --raw-output '(.Repository) + ":" + (.Tag)' - |
    sort |
    uniq |
    grep --invert-match '<none>'
}

function push_image_group
{
  local group_name="$1"

  log_info "Pushing ${group_name} images..."

  for image in $(list_images "${group_name}"); do
    log_info "Pushing ${image}..."
    quiet docker push \
      "${image}"
  done
}

function push_images
{
  push_image_group "external"
  push_image_group "base"
  push_image_group "app"
}

function main
{
  push_images

  log_info "Success $(basename "$0")"
}

main
