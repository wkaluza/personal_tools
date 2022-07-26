set -euo pipefail
if command -v shopt &>/dev/null; then
  shopt -s inherit_errexit
fi
THIS_SCRIPT_DIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"
cd "${THIS_SCRIPT_DIR}"

source "${THIS_SCRIPT_DIR}/shell_script_imports/logging.bash"
source "${THIS_SCRIPT_DIR}/shell_script_imports/common.bash"
source "${THIS_SCRIPT_DIR}/shell_script_imports/git_helpers.bash"
source "${THIS_SCRIPT_DIR}/shell_script_imports/gogs_helpers.bash"

source <(cat "${THIS_SCRIPT_DIR}/local_domains.json" |
  jq '. | to_entries' - |
  jq '. | map( "\(.key)=\"\(.value)\"" )' - |
  jq --raw-output '. | .[]' - |
  sort)

function ping_hub_from_cluster
{
  local scheme="https"
  local endpoint="_/revision"

  minikube ssh -- \
    curl --silent \
    "${scheme}://${DOMAIN_MAIN_REVERSE_PROXY_cab92795}/${endpoint}" |
    grep "vcs_in_use"
}

function ensure_connection_to_swarm
{
  log_info "Testing connection to swarm..."

  retry_until_success \
    "ping_hub_from_cluster" \
    ping_hub_from_cluster

  log_info "Swarm connected"
}

function wait_for_k8s_node_ready
{
  log_info "Waiting for k8s node readiness..."

  kubectl wait \
    node \
    --all \
    --for="condition=Ready" \
    --timeout="60s" >/dev/null
}

function _minikube_status_raw
{
  minikube status --output "json" 2>/dev/null
}

function minikube_status
{
  local status=""

  if _minikube_status_raw >/dev/null; then
    status="$(_minikube_status_raw |
      jq --sort-keys 'if . | type == "array" then .[] else . end' - |
      jq --raw-output '. | select(.Name == "minikube") | .Host' -)"
  fi

  if [[ "${status}" == "Running" ]]; then
    echo "running"
  elif [[ "${status}" == "Stopped" ]]; then
    echo "stopped"
  else
    echo "deleted"
  fi
}

function start_minikube
{
  log_info "Starting minikube..."

  local status
  status="$(minikube_status)"

  local mirror_url="https://${DOMAIN_DOCKER_REGISTRY_MIRROR_f334ec4f}"

  local host_path="${HOME}/.wk_k8s_storage___/minikube"
  local node_path="/wk_data"

  mkdir --parents "${host_path}"

  if [[ "${status}" == "deleted" ]]; then
    minikube start \
      --cpus 8 \
      --disk-size "100G" \
      --driver "docker" \
      --embed-certs \
      --memory "8G" \
      --mount "true" \
      --mount-string "${host_path}:${node_path}" \
      --nodes 2 \
      --registry-mirror="${mirror_url}" >/dev/null 2>&1
  elif [[ "${status}" == "stopped" ]]; then
    minikube start >/dev/null 2>&1
  fi
}

function install_root_ca_minikube
{
  log_info "Installing CA..."

  cp \
    "$(mkcert -CAROOT)/rootCA.pem" \
    "${HOME}/.minikube/certs"
}

function wait_flux_pre_check
{
  log_info "Running flux pre-check..."

  retry_until_success \
    "flux check --pre" \
    flux check --pre
}

function wait_flux_check
{
  log_info "Running flux check..."

  retry_until_success \
    "flux check" \
    flux check
}

function ensure_namespace
{
  local namespace_name="$1"

  kubectl create namespace "${namespace_name}" \
    --dry-run="client" \
    --output="yaml" |
    kubectl apply \
      --filename - \
      --wait >/dev/null
}

function reset_ssh_keys
{
  local ssh_key_name="$1"
  local auth_header="$2"
  local flux_namespace="$3"
  local flux_secret_name="$4"

  local keys_temp_dir
  keys_temp_dir="$(mktemp -d)"
  local private_key_file
  private_key_file="${keys_temp_dir}/gogs"
  local public_key_file="${private_key_file}.pub"
  pushd "${keys_temp_dir}" >/dev/null
  ssh-keygen \
    -t rsa \
    -b 4096 \
    -C "" \
    -f "${private_key_file}" \
    -P "" >/dev/null
  popd >/dev/null

  ensure_namespace \
    "${flux_namespace}"

  kubectl create secret generic \
    "${flux_secret_name}" \
    --from-file=identity="${private_key_file}" \
    --from-file=identity.pub="${public_key_file}" \
    --from-literal=known_hosts="$(ssh-keyscan "${DOMAIN_GIT_FRONTEND_df29c969}" 2>/dev/null | grep -Ev '^# ')" \
    --dry-run="client" \
    --namespace="${flux_namespace}" \
    --output="yaml" |
    kubectl apply --filename - >/dev/null

  gogs_delete_ssh_key \
    "${DOMAIN_GIT_FRONTEND_df29c969}" \
    "${ssh_key_name}" \
    "${auth_header}" || true
  gogs_create_ssh_key \
    "${DOMAIN_GIT_FRONTEND_df29c969}" \
    "${ssh_key_name}" \
    "$(cat "${public_key_file}")" \
    "${auth_header}"

  rm -rf "${keys_temp_dir}"

  retry_until_success \
    "keys_exist_and_match" \
    keys_exist_and_match \
    "${username}" \
    "${ssh_key_name}" \
    "${auth_header}" \
    "${flux_namespace}" \
    "${flux_secret_name}"
}

function wait_for_flux_crds
{
  local namespace="$1"

  local app_part_of="app.kubernetes.io/part-of"
  local app_instance="app.kubernetes.io/instance"

  kubectl wait \
    crd \
    --for "condition=Established" \
    --selector "${app_part_of}=flux,${app_instance}=${namespace}"
}

function apply_flux_manifests
{
  local manifests_path="$1"
  local flux_namespace="$2"

  log_info "Applying flux manifests..."
  if ! kubectl apply \
    --kustomize "${manifests_path}"; then
    # CRDs may not have been established in time to instantiate them.
    # This is a known race condition in k8s.
    # Quick and dirty workaround: wait and retry.
    wait_for_flux_crds \
      "${flux_namespace}"
    kubectl apply \
      --kustomize "${manifests_path}"
  fi
}

function set_up_gitops_infrastructure
{
  local username="$1"
  local repo_name="$2"
  local flux_namespace="$3"

  local infra_temp_dir="${HOME}/.wk_infrastructure___"
  local cluster_subdir="clusters/local_dev_pcspec"
  local manifests_root="${infra_temp_dir}/${cluster_subdir}"
  local manifests_path="${manifests_root}/${flux_namespace}"

  wait_flux_pre_check

  clone_or_fetch \
    "git@${DOMAIN_GIT_FRONTEND_df29c969}:${username}/${repo_name}.git" \
    "${infra_temp_dir}" >/dev/null 2>&1

  pushd "${infra_temp_dir}" >/dev/null
  git_get_latest >/dev/null 2>&1
  apply_flux_manifests \
    "${manifests_path}" \
    "${flux_namespace}" >/dev/null 2>&1
  popd >/dev/null

  wait_flux_check
}

function normalise_ssh_key
{
  cat - |
    tr -d '\n' |
    sed -E 's/^([a-z\-]+ [a-zA-Z0-9+/=]+).*$/\1/'
}

function keys_exist_and_match
{
  local username="$1"
  local ssh_key_name="$2"
  local auth_header="$3"
  local flux_namespace="$4"
  local flux_secret_name="$5"

  local k8s_key
  k8s_key="$(kubectl get secret \
    "${flux_secret_name}" \
    --namespace "${flux_namespace}" \
    --output "json" 2>/dev/null |
    jq --raw-output '.data."identity.pub"' - |
    base64 -d |
    normalise_ssh_key)"

  local gogs_key
  gogs_key="$(gogs_ssh_key_exists \
    "${DOMAIN_GIT_FRONTEND_df29c969}" \
    "${username}" \
    "${ssh_key_name}" \
    "${auth_header}" |
    normalise_ssh_key)"

  diff \
    <(echo "${k8s_key}") \
    <(echo "${gogs_key}") >/dev/null 2>&1
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

function connect_container_to_network
{
  local network="$1"
  local container="$2"

  docker network connect \
    "${network}" \
    "${container}"
}

function connect_stacks_to_minikube
{
  log_info "Connecting stack containers to minikube network..."

  list_all_stacks |
    for_each list_stack_services |
    for_each list_service_tasks |
    for_each list_task_containers |
    for_each no_fail connect_container_to_network \
      "minikube" >/dev/null 2>&1
}

function enable_load_balancer_support
{
  minikube tunnel >/dev/null 2>&1 &
  disown
}

function taint_control_plane
{
  local role="node-role.kubernetes.io/control-plane"

  kubectl taint node \
    --selector "${role}" \
    "${role}:NoSchedule" >/dev/null ||
    true
}

function disable_default_storage_class
{
  # standard is minikube's name for the built-in storage class
  kubectl annotate \
    --overwrite \
    storageclass \
    "standard" \
    "storageclass.kubernetes.io/is-default-class=false" >/dev/null
}

function main
{
  local username="wkaluza"
  local repo_name="infrastructure"
  local ssh_key_name="gogs_flux_ssh"
  local token
  token="$(pass show "local_gogs_token_${username}")"
  local auth_header="Authorization: token ${token}"
  local flux_namespace="flux-system"
  local flux_secret_name="flux-system"

  install_root_ca_minikube
  start_minikube
  wait_for_k8s_node_ready
  connect_stacks_to_minikube
  ensure_connection_to_swarm
  taint_control_plane
  disable_default_storage_class

  enable_load_balancer_support

  if ! keys_exist_and_match \
    "${username}" \
    "${ssh_key_name}" \
    "${auth_header}" \
    "${flux_namespace}" \
    "${flux_secret_name}"; then
    log_info "Resetting SSH keys..."
    reset_ssh_keys \
      "${ssh_key_name}" \
      "${auth_header}" \
      "${flux_namespace}" \
      "${flux_secret_name}"
  fi

  set_up_gitops_infrastructure \
    "${username}" \
    "${repo_name}" \
    "${flux_namespace}"

  log_info "Success $(basename "$0")"
}

main
