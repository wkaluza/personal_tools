set -euo pipefail
if command -v shopt &>/dev/null; then
  shopt -s inherit_errexit
fi
THIS_SCRIPT_DIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"
cd "${THIS_SCRIPT_DIR}"

source "${THIS_SCRIPT_DIR}/../../shell_script_imports/common.bash"

DIGESTS=""

function compute_digest
{
  local input_string="$1"

  echo -n "${input_string}" | md5
}

function append_digest
{
  local input_string="$1"

  DIGESTS="${DIGESTS}$(compute_digest "${input_string}")"
}

function docker_run
{
  local container_name="$1"
  local uid="$2"
  local gid="$3"
  local host_workspace="$4"
  local command="$5"
  local build_context="$6"
  local image_name="$7"

  local rel_ws_to_build_ctx
  rel_ws_to_build_ctx="$(realpath \
    --relative-to="${host_workspace}" \
    "${build_context}")"

  local list_exited
  list_exited="$(docker container list \
    --no-trunc \
    --quiet \
    --filter="status=exited" \
    --filter="name=^${container_name}$")"

  if ! test -z "${list_exited}"; then
    docker rm "${container_name}"
  fi

  local docker_workspace
  docker_workspace="$(
    docker run \
      --rm \
      --tty \
      --name "${container_name}_workspace_probe" \
      --user "${uid}:${gid}" \
      "${image_name}" \
      "/bin/bash" \
      "-c" \
      'stty -onlcr && echo "${WORKSPACE}"' # prevent trailing CR in output
  )"

  echo "Running command..."
  docker run \
    --rm \
    --tty \
    --interactive \
    --publish-all \
    --env IMPORTS_DIR="${docker_workspace}/${rel_ws_to_build_ctx}" \
    --name "${container_name}" \
    --user "${uid}:${gid}" \
    --volume "${host_workspace}:${docker_workspace}" \
    --workdir "${docker_workspace}" \
    "${image_name}" \
    "/bin/bash" \
    "-c" \
    "${command}"
}

function docker_build
{
  local dockerfile="$1"
  local uid="$2"
  local gid="$3"
  local username="$4"
  local build_context="$5"
  local image_name="$6"

  echo "Building image..."
  docker build \
    --tag "${image_name}" \
    --file "${dockerfile}" \
    --build-arg UID="${uid}" \
    --build-arg GID="${gid}" \
    --build-arg USERNAME="${username}" \
    --build-arg HOST_TIMEZONE="$(current_timezone)" \
    "${build_context}" >/dev/null
}

function main
{
  local job_name="$1"
  local dockerfile
  dockerfile="$(realpath "$2")"
  local build_context
  build_context="$(realpath "$3")"
  local host_workspace
  host_workspace="$(realpath "$4")"
  local command="$5"

  local aggregate_digest
  aggregate_digest="$(compute_digest "${DIGESTS}" | cut -c1-8)"

  local image_name="${job_name}_${aggregate_digest}"
  local container_name="${job_name}"
  local uid
  uid="$(id -u)"
  local gid
  gid="$(id -g)"
  local username
  username="$(id -un)"

  docker_build \
    "${dockerfile}" \
    "${uid}" \
    "${gid}" \
    "${username}" \
    "${build_context}" \
    "${image_name}"

  docker_run \
    "${container_name}" \
    "${uid}" \
    "${gid}" \
    "${host_workspace}" \
    "${command}" \
    "${build_context}" \
    "${image_name}"
}

function main_json
{
  local root_dir
  root_dir="$(realpath "$1")"
  local json_config
  json_config="$(realpath "$2")"
  local job_name="$3"

  cd "${root_dir}"

  local dockerfile
  dockerfile="$(realpath \
    "$(jq -r ".${job_name}.dockerfile" "${json_config}")")"
  local build_context
  build_context="$(realpath \
    "$(jq -r ".${job_name}.build_context" "${json_config}")")"
  local host_workspace
  host_workspace="$(realpath \
    "$(jq -r ".${job_name}.host_workspace" "${json_config}")")"
  local command
  command="$(jq -r ".${job_name}.command | join(\" \")" "${json_config}")"

  append_digest "$(realpath "${build_context}")"
  append_digest "$(realpath "${host_workspace}")"
  append_digest "$(realpath "${dockerfile}")"
  append_digest "$(cat "$(realpath "${dockerfile}")")"
  append_digest "$(realpath "${json_config}")"
  append_digest "$(cat "$(realpath "${json_config}")")"
  append_digest "$(realpath "${BASH_SOURCE[0]}")"
  append_digest "$(cat "$(realpath "${BASH_SOURCE[0]}")")"
  append_digest "${command}"

  main \
    "${job_name}" \
    "${dockerfile}" \
    "${build_context}" \
    "${host_workspace}" \
    "${command}"

  echo "Success: $(basename "$0")"
}

# Entry point
main_json "$1" "$2" "$3"
