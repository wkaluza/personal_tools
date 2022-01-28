#!/usr/bin/env bash

set -euo pipefail

IMAGE_NAME=""

function on_exit {
  docker rmi --no-prune "${IMAGE_NAME}"
}

trap on_exit EXIT

function docker_run
{
  local container_name="$1"
  local uid="$2"
  local gid="$3"
  local host_workspace="$4"
  local command="$5"
  local build_context="$6"

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
      --rm \
      --tty \
      --name "${container_name}_workspace_probe" \
      --user "${uid}:${gid}" \
      "${IMAGE_NAME}" \
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
    "${IMAGE_NAME}" \
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

  docker build \
    --tag "${IMAGE_NAME}" \
    --file "${dockerfile}" \
    --build-arg UID="${uid}" \
    --build-arg GID="${gid}" \
    --build-arg USERNAME="${username}" \
    "${build_context}"
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

  IMAGE_NAME="${job_name}"
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
    "${build_context}"

  docker_run \
    "${container_name}" \
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
    "${job_name}" \
    "${dockerfile}" \
    "${build_context}" \
    "${host_workspace}" \
    "${command}"
}

# Entry point
main_json "$1" "$2" "$3"
