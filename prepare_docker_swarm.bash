set -euo pipefail
shopt -s inherit_errexit

function get_swarm_state
{
  docker system info --format='{{json .}}' |
    jq -r --sort-keys '.Swarm.LocalNodeState' -
}

# Note: recursive function
function ensure_docker_swarm_init
{
  local swarm_state="$(get_swarm_state)"

  local primary_key="174C9368811039C87F0C806A896572D1E78ED6A7"
  local encryption_subkey="217BB178444E212F714DBAC90FBB9BD0E486C169"

  local swarm_key_pass_id="wk_local_swarm_key"
  local swarm_key_magic_prefix="SWMKEY"

  if [[ "${swarm_state}" == "locked" ]]; then
    echo "Swarm is locked, unlocking..."
    if pass show "${swarm_key_pass_id}" >/dev/null &&
      pass show "${swarm_key_pass_id}" |
      docker swarm unlock >/dev/null 2>&1; then
      echo "Swarm unlocked successfully"
    else
      echo "Cannot unlock swarm, need to leave and re-init..."

      docker swarm leave --force

      ensure_docker_swarm_init
    fi
  elif [[ "${swarm_state}" == "inactive" ]]; then
    echo "Swarm is inactive, initialising..."

    docker swarm init --autolock |
      grep "${swarm_key_magic_prefix}" |
      sed -E "s/^.*(${swarm_key_magic_prefix}.*)$/\1/" |
      pass insert --multiline "${swarm_key_pass_id}" >/dev/null

    echo "Swarm is now active"
  elif [[ "${swarm_state}" == "active" ]]; then
    echo "Swarm is active"
  else
    echo "Error: unexpected docker swarm state '${swarm_state}'"
    exit 1
  fi
}

function is_docker_registry_running
{
  local registry_service_name="$1"

  docker service ls --format='{{json .Name}}' |
    jq -r --sort-keys '.' - |
    grep -E "^${registry_service_name}$" >/dev/null
}

function get_local_node_id
{
  docker node ls --format='{{ json . }}' |
    jq -s --sort-keys '.' - |
    jq --sort-keys '. | map(select( .Self == true ))' - |
    jq -r --sort-keys 'if . | length == 1 then .[0].ID else error("Expected exactly one local node") end' -
}

function start_docker_registry
{
  local registry_service_name="$1"
  local registry_port="$2"
  local local_node_id="$3"

  local registry_image_version="2.8.1"

  local port_info="published=${registry_port},target=5000,mode=ingress,protocol=tcp"
  local volume_info="type=volume,source=${registry_service_name}_volume,destination=/var/lib/registry"

  echo "Starting service ${registry_service_name}..."

  if docker service create \
    --constraint "node.id==${local_node_id}" \
    --mode "global" \
    --mount "${volume_info}" \
    --name "${registry_service_name}" \
    --publish "${port_info}" \
    --quiet \
    "registry:${registry_image_version}" >/dev/null; then
    echo "Service ${registry_service_name} started successfully"
  else
    echo "Error: failed to start service ${registry_service_name}"
  fi
}

function ensure_local_docker_registry_is_running
{
  local registry_port=5555
  local local_docker_registry_service_name="local_docker_registry"

  local local_node_id
  local_node_id="$(get_local_node_id)"

  if ! is_docker_registry_running "${local_docker_registry_service_name}"; then
    start_docker_registry \
      "${local_docker_registry_service_name}" \
      "${registry_port}" \
      "${local_node_id}"
  fi
}

function main
{
  ensure_docker_swarm_init
  ensure_local_docker_registry_is_running
}

main
