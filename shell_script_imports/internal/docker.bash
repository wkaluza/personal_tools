set -euo pipefail
if command -v shopt &>/dev/null; then
  shopt -s inherit_errexit
fi

function get_local_node_id
{
  docker node ls --format='{{ json . }}' |
    jq --slurp '. | map(select( .Self == true ))' - |
    jq \
      --raw-output \
      'if . | length == 1 then .[0].ID else error("Expected exactly one local node") end' -
}

function is_stack_running
{
  local stack_name="$1"

  docker stack ls --format '{{ json . }}' |
    jq \
      --slurp \
      "map(select( .Name == \"${stack_name}\" ))" - |
    jq \
      --raw-output \
      'if . | length == 1 then .[0].Name else error("Expected stack not found") end' - 2>/dev/null |
    head -n 1 |
    grep -E "^${stack_name}$" >/dev/null
}

function stack_internal_networks
{
  local stack_name="$1"
  local compose_file="$2"

  cat "${compose_file}" |
    jq --raw-output '.networks | keys | .[]' - |
    grep "internal" |
    awk "{ print \"${stack_name}_\" \$0 }" |
    sort
}

function wait_for_networks_deletion
{
  local stack_name="$1"
  local compose_file="$2"

  for network_name in $(stack_internal_networks \
    "${stack_name}" \
    "${compose_file}"); do
    if docker network ls --format '{{ .Name }}' |
      grep -E "^${network_name}$" >/dev/null; then
      false
    fi
  done
}

function wait_for_stack_readiness
{
  local stack_name="$1"

  list_stack_services "${stack_name}" |
    for_each list_service_tasks |
    for_each get_task_containers_state |
    for_each strings_are_equal "running"
}

function start_docker_stack
{
  local env_factory="$1"
  local compose_file="$2"
  local stack_name="$3"

  docker stack rm \
    "${stack_name}" >/dev/null 2>&1 ||
    true

  retry_until_success \
    "wait_for_networks_deletion" \
    wait_for_networks_deletion \
    "${stack_name}" \
    "${compose_file}"

  log_info "Building ${stack_name} images..."

  run_with_env \
    "${env_factory}" \
    docker compose \
    --file "${compose_file}" \
    build

  log_info "Deploying ${stack_name}..."

  run_with_env \
    "${env_factory}" \
    docker stack deploy \
    --compose-file "${compose_file}" \
    --prune \
    "${stack_name}"

  log_info "Stack ${stack_name} deployed successfully"

  log_info "Pushing ${stack_name} images..."

  run_with_env \
    "${env_factory}" \
    docker compose \
    --file "${compose_file}" \
    push

  log_info "Stack ${stack_name} pushed successfully"

  retry_until_success \
    "wait_for_stack_readiness" \
    wait_for_stack_readiness \
    "${stack_name}"
}

function list_all_stacks
{
  docker stack ls --format '{{ .Name }}'
}

function list_stack_services
{
  local stack="$1"

  docker stack services \
    --format '{{ .ID }}' \
    "${stack}"
}

function list_service_tasks
{
  local service="$1"

  docker service ps \
    --no-trunc \
    --format '{{ .ID }}' \
    "${service}"
}

function list_task_containers
{
  local task="$1"

  docker inspect \
    --format '{{ .Status.ContainerStatus.ContainerID }}' \
    "${task}"
}

function get_task_containers_state
{
  local task="$1"

  docker inspect \
    --format '{{ .Status.State }}' \
    "${task}"
}

function connect_container_to_network
{
  local network="$1"
  local ip="$2"
  local container="$3"

  if [[ "${ip}" == "auto" ]]; then
    docker network connect \
      "${network}" \
      "${container}"
  else
    docker network connect \
      --ip "${ip}" \
      "${network}" \
      "${container}"
  fi
}

function container_has_label
{
  local label_name="$1"
  local label_value="$2"
  local container_id="$3"

  docker container list \
    --no-trunc \
    --filter label="${label_name}=${label_value}" \
    --format '{{ json . }}' |
    jq --raw-output '.ID' - |
    grep -E "^${container_id}$"
}

function connect_stack_containers_to_network
{
  local network="$1"
  local ip="$2"
  local label_name="$3"
  local label_value="$4"
  local stack="$5"

  list_stack_services \
    "${stack}" |
    for_each list_service_tasks |
    for_each list_task_containers |
    for_each filter container_has_label \
      "${label_name}" \
      "${label_value}" |
    for_each no_fail connect_container_to_network \
      "${network}" \
      "${ip}" >/dev/null 2>&1
}
