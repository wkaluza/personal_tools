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

DOCKER_USERNAME="sostratus"
DOCKER_UID="54321"
DOCKER_GID="43210"

HOST_TIMEZONE="$(current_timezone)"

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

function process_image
{
  local input_image="$1"
  local output_image="$2"
  local dockerfile="$3"
  local target_image="$4"
  local context="$5"

  log_info "Processing image ${input_image} to ${output_image}..."

  docker build \
    --file "${dockerfile}" \
    --tag "${output_image}" \
    --target "${target_image}" \
    --build-arg IMAGE="${input_image}" \
    --build-arg DOCKER_USERNAME="${DOCKER_USERNAME}" \
    "${context}"
}

function add_image_epilogue
{
  local input_image="$1"
  local output_image="$2"

  local meta_dir="${THIS_SCRIPT_DIR}/docker/images/meta"

  process_image \
    "${input_image}" \
    "${output_image}" \
    "${meta_dir}/epilogue.dockerfile" \
    "epilogue-bash-user-wo3sglfw" \
    "${meta_dir}/context/" >/dev/null 2>&1
}

function _build_image
{
  local source_image_ref="$1"
  local final_image_ref="$2"
  local dockerfile="$3"
  local context="$4"

  docker build \
    --file "${dockerfile}" \
    --tag "${final_image_ref}" \
    --build-arg HOST_TIMEZONE="${HOST_TIMEZONE}" \
    --build-arg IMAGE="${source_image_ref}" \
    --build-arg DOCKER_USERNAME="${DOCKER_USERNAME}" \
    --build-arg DOCKER_UID="${DOCKER_UID}" \
    --build-arg DOCKER_GID="${DOCKER_GID}" \
    "${context}" >/dev/null 2>&1
}

function build_base_image
{
  local source_name="$1"
  local source_tag="$2"
  local destination_tag="$3"
  local dockerfile="$4"
  local context="$5"

  local final_image_ref="${BASE_IMAGE_PREFIX}/${source_name}/${source_tag}:${destination_tag}"
  local source_image_ref="${EXTERNAL_IMAGE_PREFIX}/${source_name}/${source_tag}:${destination_tag}"

  log_info "Building image ${final_image_ref}..."

  _build_image \
    "${source_image_ref}" \
    "${final_image_ref}" \
    "${dockerfile}" \
    "${context}"
}

function build_app_image
{
  local source_image="$1"
  local source_tag="$2"
  local destination_name="$3"
  local destination_tag="$4"
  local dockerfile="$5"
  local context="$6"

  local final_image_ref="${APP_IMAGE_PREFIX}/${destination_name}:${destination_tag}"
  local source_image_ref="${source_image}:${source_tag}"

  log_info "Building image ${final_image_ref}..."

  _build_image \
    "${source_image_ref}" \
    "${final_image_ref}" \
    "${dockerfile}" \
    "${context}"
}

function build_app_image_with_epilogue
{
  local source_image="$1"
  local source_tag="$2"
  local destination_name="$3"
  local destination_tag="$4"
  local dockerfile="$5"
  local context="$6"

  local final_image_ref="${APP_IMAGE_PREFIX}/${destination_name}:${destination_tag}"
  local source_image_ref="${source_image}:${source_tag}"
  local temp_image_ref
  temp_image_ref="temp_$(openssl rand -hex 8)"

  log_info "Building image ${final_image_ref}..."

  _build_image \
    "${source_image_ref}" \
    "${temp_image_ref}" \
    "${dockerfile}" \
    "${context}"

  add_image_epilogue \
    "${temp_image_ref}" \
    "${final_image_ref}"

  docker rmi \
    --force \
    --no-prune \
    "${temp_image_ref}" >/dev/null 2>&1
}

function main
{
  local base_dir="${THIS_SCRIPT_DIR}/docker/images/base"
  local app_dir="${THIS_SCRIPT_DIR}/docker/images/app"

  pull_retag_external \
    "ubuntu" \
    "22.04" \
    "1"

  pull_retag_external \
    "coredns/coredns" \
    "1.10.0" \
    "1"

  pull_retag_external \
    "gogs/gogs" \
    "0.12.6" \
    "1"

  pull_retag_external \
    "registry" \
    "2.8.1" \
    "1"

  pull_retag_external \
    "nginx" \
    "1.21.6-alpine" \
    "1"

  build_base_image \
    "ubuntu" \
    "22.04" \
    "1" \
    "${base_dir}/ubuntu/ubuntu.dockerfile" \
    "${base_dir}/ubuntu/context"

  build_app_image_with_epilogue \
    "${BASE_IMAGE_PREFIX}/ubuntu/22.04" \
    "1" \
    "dns_tools" \
    "1" \
    "${app_dir}/dns_tools/dns_tools.dockerfile" \
    "${app_dir}/dns_tools/context"

  build_app_image_with_epilogue \
    "${BASE_IMAGE_PREFIX}/ubuntu/22.04" \
    "1" \
    "git" \
    "1" \
    "${app_dir}/git/git.dockerfile" \
    "${app_dir}/git/context"

  build_app_image \
    "${EXTERNAL_IMAGE_PREFIX}/coredns/coredns/1.10.0" \
    "1" \
    "dns" \
    "1" \
    "${app_dir}/dns/dns.dockerfile" \
    "${app_dir}/dns/context"

  build_app_image \
    "${EXTERNAL_IMAGE_PREFIX}/registry/2.8.1" \
    "1" \
    "registry" \
    "1" \
    "${app_dir}/registry/registry.dockerfile" \
    "${app_dir}/registry/context"

  bash "${app_dir}/git_frontend/prepare_build_context.bash"
  build_app_image \
    "${EXTERNAL_IMAGE_PREFIX}/gogs/gogs/0.12.6" \
    "1" \
    "gogs" \
    "1" \
    "${app_dir}/git_frontend/git_frontend.dockerfile" \
    "${app_dir}/git_frontend/context"

  build_app_image \
    "${EXTERNAL_IMAGE_PREFIX}/nginx/1.21.6-alpine" \
    "1" \
    "nginx" \
    "1" \
    "${app_dir}/reverse_proxy/reverse_proxy.dockerfile" \
    "${app_dir}/reverse_proxy/context"

  log_info "Success $(basename "$0")"
}

main
