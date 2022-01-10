#!/usr/bin/env bash

set -euo pipefail

function docker_run
{
  local container_name="$1"
  local image_name_with_tag="$2"
  local uid="$3"
  local gid="$4"
  local host_workspace="$5"
  local command="$6"
  local build_context="$7"

  local rel_ws_to_build_ctx
  rel_ws_to_build_ctx="$(realpath \
    --relative-to="${host_workspace}" \
    "${build_context}")"

  local list_exited
  list_exited="$(docker container list \
    --quiet \
    --filter="status=exited" \
    --filter="name=^${container_name}$")"

  if ! test -z "${list_exited}"; then
    docker rm "${container_name}"
  fi

  local docker_workspace
  docker_workspace="$(
    docker run \
      --tty \
      --rm \
      --name "${container_name}_workspace_probe" \
      --user "${uid}:${gid}" \
      "${image_name_with_tag}" \
      "/bin/bash" \
      "-c" \
      'stty -onlcr && echo "${WORKSPACE}"' # prevent trailing CR in output
  )"

  docker run \
    --rm \
    --tty \
    --interactive \
    --env IMPORTS_DIR="${docker_workspace}/${rel_ws_to_build_ctx}" \
    --name "${container_name}" \
    --user "${uid}:${gid}" \
    --volume "${host_workspace}:${docker_workspace}" \
    --workdir "${docker_workspace}" \
    "${image_name_with_tag}" \
    "/bin/bash" \
    "-c" \
    "${command}"
}

function docker_build
{
  local image_name_with_tag="$1"
  local dockerfile="$2"
  local uid="$3"
  local gid="$4"
  local username="$5"
  local build_context="$6"

  docker build \
    --tag "${image_name_with_tag}" \
    --file "${dockerfile}" \
    --build-arg UID="${uid}" \
    --build-arg GID="${gid}" \
    --build-arg USERNAME="${username}" \
    "${build_context}"
}

function main
{
  local docker_image="$1"
  local dockerfile
  dockerfile="$(realpath "$2")"
  local build_context
  build_context="$(realpath "$3")"
  local host_workspace
  host_workspace="$(realpath "$4")"
  local command="$5"

  local image_name_with_tag="${docker_image}:auto"
  local container_name="${docker_image}"

  local uid
  uid="$(id -u)"
  local gid
  gid="$(id -g)"
  local username
  username="$(id -un)"

  docker_build \
    "${image_name_with_tag}" \
    "${dockerfile}" \
    "${uid}" \
    "${gid}" \
    "${username}" \
    "${build_context}"

  docker_run \
    "${container_name}" \
    "${image_name_with_tag}" \
    "${uid}" \
    "${gid}" \
    "${host_workspace}" \
    "${command}" \
    "${build_context}"
}

function main_json
{
  local root_dir
  root_dir="$(realpath "$1")"
  local json_config
  json_config="$(realpath "$2")"
  local job_name="$3"

  cd "${root_dir}"

  local docker_image="${job_name}"
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

  main \
    "${docker_image}" \
    "${dockerfile}" \
    "${build_context}" \
    "${host_workspace}" \
    "${command}"
}

# Entry point
main_json "$1" "$2" "$3"
