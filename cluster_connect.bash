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

function minikube_docker_container_id
{
  docker container list --all \
    --format '{{ json . }}' |
    jq --raw-output '. | select(.Names == "minikube") | .ID'
}

function k8s_node_ready
{
  kubectl get node minikube --output json |
    jq '. | select(.metadata.name == "minikube")' - |
    jq '. | .status.conditions[]' - |
    jq '. | select(.type == "Ready")' - |
    jq '. | select(.reason == "KubeletReady")' - |
    jq -r '.status' - |
    grep -E "^True$" >/dev/null
}

function wait_for_k8s_node_ready
{
  retry_until_success \
    "k8s_node_ready" \
    k8s_node_ready

  log_info "k8s node is ready"
}

function minikube_status
{
  local status=""

  if minikube status --output json >/dev/null; then
    status="$(minikube status --output json |
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

  if [[ "${status}" == "deleted" ]]; then
    minikube start \
      --cpus 8 \
      --disk-size "100G" \
      --driver "docker" \
      --embed-certs \
      --memory "8G" \
      --nodes 1 >/dev/null 2>&1
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

function connect_local_docker_network
{
  local external_network_name="$1"

  log_info "Connecting docker network..."

  docker network connect \
    "${external_network_name}" \
    "$(minikube_docker_container_id)" >/dev/null 2>&1
}

function disconnect_local_docker_network
{
  local external_network_name="$1"

  log_info "Disconnecting docker network..."

  docker network disconnect \
    "${external_network_name}" \
    "$(minikube_docker_container_id)" >/dev/null 2>&1
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

function set_up_gitops_infrastructure
{
  local username="$1"
  local repo_name="$2"
  local flux_namespace="$3"

  local infra_temp_dir="${HOME}/.infrastructure___"
  local cluster_subdir="clusters/local_dev_pcspec"
  local manifests_root="${infra_temp_dir}/${cluster_subdir}"
  local manifests_path="${manifests_root}/${flux_namespace}"

  wait_flux_pre_check

  log_info "Cloning..."
  clone_or_fetch \
    "git@${DOMAIN_GIT_FRONTEND_df29c969}:${username}/${repo_name}.git" \
    "${infra_temp_dir}" >/dev/null 2>&1

  pushd "${infra_temp_dir}" >/dev/null
  git_get_latest >/dev/null 2>&1

  log_info "Applying flux manifests..."
  kubectl apply \
    --kustomize "${manifests_path}" >/dev/null
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
    --output "json" |
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

  local external_network_name
  external_network_name="$(bash "${THIS_SCRIPT_DIR}/create_external_docker_network.bash")"

  install_root_ca_minikube
  disconnect_local_docker_network \
    "${external_network_name}" ||
    true
  start_minikube
  wait_for_k8s_node_ready
  connect_local_docker_network \
    "${external_network_name}"
  ensure_connection_to_swarm

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
