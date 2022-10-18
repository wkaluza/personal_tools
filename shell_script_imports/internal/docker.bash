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
}
