set -euo pipefail
if command -v shopt &>/dev/null; then
  shopt -s inherit_errexit
fi
THIS_SCRIPT_DIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"
cd "${THIS_SCRIPT_DIR}"

source "${THIS_SCRIPT_DIR}/shell_script_imports/preamble.bash"

APP_IMAGE_PREFIX="${DOMAIN_DOCKER_REGISTRY_PRIVATE_a8a1ce1e}/app"
BASE_IMAGE_PREFIX="${DOMAIN_DOCKER_REGISTRY_PRIVATE_a8a1ce1e}/base"
EXTERNAL_IMAGE_PREFIX="${DOMAIN_DOCKER_REGISTRY_PRIVATE_a8a1ce1e}/external"
USERNAME="sostratus"

function pull_retag_external
{
  local source_name="$1"
  local source_tag="$2"
  local destination_tag="$3"

  local old="${source_name}:${source_tag}"
  local new
  new="${EXTERNAL_IMAGE_PREFIX}/${source_name}/${source_tag}:${destination_tag}"

  docker pull \
    "${old}" >/dev/null 2>&1
  docker tag \
    "${old}" \
    "${new}" >/dev/null 2>&1
}

function squash_image
{
  local input_image="$1"
  local output_image="$2"

  log_info "Squashing image ${output_image}..."

  local squash_dir="${THIS_SCRIPT_DIR}/docker/images/squash"

  docker build \
    --file "${squash_dir}/squash.dockerfile" \
    --tag "${output_image}" \
    --target "flat-lu5k0qbb" \
    --build-arg IMAGE="${input_image}" \
    "${squash_dir}/context/" >/dev/null 2>&1
}

function squash_image_with_user
{
  local input_image="$1"
  local output_image="$2"

  log_info "Squashing image ${output_image}..."

  local squash_dir="${THIS_SCRIPT_DIR}/docker/images/squash"

  docker build \
    --file "${squash_dir}/squash.dockerfile" \
    --tag "${output_image}" \
    --target "flat-bash-user-wo3sglfw" \
    --build-arg IMAGE="${input_image}" \
    --build-arg USERNAME="${USERNAME}" \
    "${squash_dir}/context/" >/dev/null 2>&1
}

function build_base_image
{
  local source_name="$1"
  local source_tag="$2"
  local destination_tag="$3"
  local dockerfile="$4"
  local context="$5"

  local final_tag="${BASE_IMAGE_PREFIX}/${source_name}/${source_tag}:${destination_tag}"
  local temp_tag
  temp_tag="$(openssl rand -hex 8)"

  local uid="54321"
  local gid="43210"

  log_info "Building image ${final_tag}..."

  docker build \
    --file "${dockerfile}" \
    --tag "${temp_tag}" \
    --build-arg HOST_TIMEZONE="$(cat /etc/timezone)" \
    --build-arg IMAGE="${EXTERNAL_IMAGE_PREFIX}/${source_name}/${source_tag}:${destination_tag}" \
    --build-arg USERNAME="${USERNAME}" \
    --build-arg UID="${uid}" \
    --build-arg GID="${gid}" \
    "${context}" >/dev/null 2>&1

  squash_image \
    "${temp_tag}" \
    "${final_tag}"

  docker rmi \
    --force \
    --no-prune \
    "${temp_tag}" >/dev/null 2>&1
}

function build_app_image
{
  local source_image="$1"
  local source_tag="$2"
  local destination_name="$3"
  local destination_tag="$4"
  local dockerfile="$5"
  local context="$6"

  local final_tag="${APP_IMAGE_PREFIX}/${destination_name}:${destination_tag}"
  local temp_tag
  temp_tag="$(openssl rand -hex 8)"

  log_info "Building image ${final_tag}..."

  docker build \
    --file "${dockerfile}" \
    --tag "${temp_tag}" \
    --build-arg IMAGE="${source_image}:${source_tag}" \
    "${context}" >/dev/null 2>&1

  squash_image_with_user \
    "${temp_tag}" \
    "${final_tag}"

  docker rmi \
    --force \
    --no-prune \
    "${temp_tag}" >/dev/null 2>&1
}

function main
{
  local base_dir="${THIS_SCRIPT_DIR}/docker/images/base"
  local app_dir="${THIS_SCRIPT_DIR}/docker/images/app"

  pull_retag_external \
    "ubuntu" \
    "22.04" \
    "1"

  build_base_image \
    "ubuntu" \
    "22.04" \
    "1" \
    "${base_dir}/ubuntu/ubuntu.dockerfile" \
    "${base_dir}/ubuntu/context"

  build_app_image \
    "${BASE_IMAGE_PREFIX}/ubuntu/22.04" \
    "1" \
    "dns_tools" \
    "1" \
    "${app_dir}/dns_tools/dns_tools.dockerfile" \
    "${app_dir}/dns_tools/context"

  build_app_image \
    "${BASE_IMAGE_PREFIX}/ubuntu/22.04" \
    "1" \
    "git" \
    "1" \
    "${app_dir}/git/git.dockerfile" \
    "${app_dir}/git/context"

  log_info "Success $(basename "$0")"
}

main
