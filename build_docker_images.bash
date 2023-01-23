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

  quiet docker pull \
    "${old}"
  quiet docker tag \
    "${old}" \
    "${new}"
}

function process_image
{
  local input_image="$1"
  local output_image="$2"
  local dockerfile_target="$3"
  local dockerfile="$4"
  local context="$5"
  local username="$6"

  log_info "Processing image ${input_image} to ${output_image}..."

  docker build \
    --file "${dockerfile}" \
    --tag "${output_image}" \
    --target "${dockerfile_target}" \
    --build-arg IMAGE="${input_image}" \
    --build-arg DOCKER_USERNAME="${username}" \
    "${context}"
}

function add_image_epilogue
{
  local input_image="$1"
  local output_image="$2"
  local username="$3"

  local meta_dir="${THIS_SCRIPT_DIR}/docker/images/meta"

  quiet process_image \
    "${input_image}" \
    "${output_image}" \
    "epilogue-bash-user-wo3sglfw" \
    "${meta_dir}/epilogue.dockerfile" \
    "${meta_dir}/context/" \
    "${username}"
}

function _build_image
{
  local source_image_ref="$1"
  local final_image_ref="$2"
  local dockerfile_target="$3"
  local dockerfile="$4"
  local context="$5"
  local username="$6"
  local user_id="$7"
  local group_id="$8"

  quiet docker build \
    --file "${dockerfile}" \
    --tag "${final_image_ref}" \
    --target "${dockerfile_target}" \
    --build-arg HOST_TIMEZONE="${HOST_TIMEZONE}" \
    --build-arg IMAGE="${source_image_ref}" \
    --build-arg DOCKER_USERNAME="${username}" \
    --build-arg DOCKER_UID="${user_id}" \
    --build-arg DOCKER_GID="${group_id}" \
    "${context}"
}

function build_base_image
{
  local source_name="$1"
  local external_tag="$2"
  local source_tag="$3"
  local destination_tag="$4"
  local dockerfile_target="$5"
  local dockerfile="$6"
  local context="$7"
  local username="$8"
  local user_id="$9"
  local group_id="${10}"

  local final_image_ref="${BASE_IMAGE_PREFIX}/${source_name}/${external_tag}:${destination_tag}"
  local source_image_ref="${EXTERNAL_IMAGE_PREFIX}/${source_name}/${external_tag}:${source_tag}"

  log_info "Building image ${final_image_ref}..."

  _build_image \
    "${source_image_ref}" \
    "${final_image_ref}" \
    "${dockerfile_target}" \
    "${dockerfile}" \
    "${context}" \
    "${username}" \
    "${user_id}" \
    "${group_id}"
}

function build_app_image
{
  local source_image="$1"
  local source_tag="$2"
  local destination_name="$3"
  local destination_tag="$4"
  local dockerfile_target="$5"
  local dockerfile="$6"
  local context="$7"
  local username="$8"
  local user_id="$9"
  local group_id="${10}"

  local final_image_ref="${APP_IMAGE_PREFIX}/${destination_name}:${destination_tag}"
  local source_image_ref="${source_image}:${source_tag}"

  log_info "Building image ${final_image_ref}..."

  _build_image \
    "${source_image_ref}" \
    "${final_image_ref}" \
    "${dockerfile_target}" \
    "${dockerfile}" \
    "${context}" \
    "${username}" \
    "${user_id}" \
    "${group_id}"
}

function build_app_image_with_epilogue
{
  local source_image="$1"
  local source_tag="$2"
  local destination_name="$3"
  local destination_tag="$4"
  local dockerfile_target="$5"
  local dockerfile="$6"
  local context="$7"
  local username="$8"
  local user_id="$9"
  local group_id="${10}"

  local final_image_ref="${APP_IMAGE_PREFIX}/${destination_name}:${destination_tag}"
  local source_image_ref="${source_image}:${source_tag}"
  local temp_image_ref
  temp_image_ref="temp_$(openssl rand -hex 8)"

  log_info "Building image ${final_image_ref}..."

  _build_image \
    "${source_image_ref}" \
    "${temp_image_ref}" \
    "${dockerfile_target}" \
    "${dockerfile}" \
    "${context}" \
    "${username}" \
    "${user_id}" \
    "${group_id}"

  add_image_epilogue \
    "${temp_image_ref}" \
    "${final_image_ref}" \
    "${username}"

  quiet docker rmi \
    --force \
    --no-prune \
    "${temp_image_ref}"
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

  bash "${base_dir}/ubuntu/prepare_build_context.bash"
  build_base_image \
    "ubuntu" \
    "22.04" \
    "1" \
    "1" \
    "base" \
    "${base_dir}/ubuntu/ubuntu.dockerfile" \
    "${base_dir}/ubuntu/context" \
    "${DOCKER_USERNAME}" \
    "${DOCKER_UID}" \
    "${DOCKER_GID}"

  build_app_image_with_epilogue \
    "${BASE_IMAGE_PREFIX}/ubuntu/22.04" \
    "1" \
    "dns_tools" \
    "1" \
    "base" \
    "${app_dir}/dns_tools/dns_tools.dockerfile" \
    "${app_dir}/dns_tools/context" \
    "${DOCKER_USERNAME}" \
    "${DOCKER_UID}" \
    "${DOCKER_GID}"

  build_app_image_with_epilogue \
    "${BASE_IMAGE_PREFIX}/ubuntu/22.04" \
    "1" \
    "git" \
    "1" \
    "base" \
    "${app_dir}/git/git.dockerfile" \
    "${app_dir}/git/context" \
    "${DOCKER_USERNAME}" \
    "${DOCKER_UID}" \
    "${DOCKER_GID}"

  build_app_image \
    "${EXTERNAL_IMAGE_PREFIX}/coredns/coredns/1.10.0" \
    "1" \
    "dns" \
    "1" \
    "base" \
    "${app_dir}/dns/dns.dockerfile" \
    "${app_dir}/dns/context" \
    "${DOCKER_USERNAME}" \
    "${DOCKER_UID}" \
    "${DOCKER_GID}"

  build_app_image \
    "${EXTERNAL_IMAGE_PREFIX}/registry/2.8.1" \
    "1" \
    "registry" \
    "1" \
    "base" \
    "${app_dir}/registry/registry.dockerfile" \
    "${app_dir}/registry/context" \
    "${DOCKER_USERNAME}" \
    "${DOCKER_UID}" \
    "${DOCKER_GID}"

  bash "${app_dir}/git_frontend/prepare_build_context.bash"
  build_app_image \
    "${EXTERNAL_IMAGE_PREFIX}/gogs/gogs/0.12.6" \
    "1" \
    "gogs" \
    "1" \
    "base" \
    "${app_dir}/git_frontend/git_frontend.dockerfile" \
    "${app_dir}/git_frontend/context" \
    "${DOCKER_USERNAME}" \
    "${DOCKER_UID}" \
    "${DOCKER_GID}"

  build_app_image \
    "${EXTERNAL_IMAGE_PREFIX}/nginx/1.21.6-alpine" \
    "1" \
    "nginx" \
    "1" \
    "base" \
    "${app_dir}/reverse_proxy/reverse_proxy.dockerfile" \
    "${app_dir}/reverse_proxy/context" \
    "${DOCKER_USERNAME}" \
    "${DOCKER_UID}" \
    "${DOCKER_GID}"

  log_info "Success $(basename "$0")"
}

main
