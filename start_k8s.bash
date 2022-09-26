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
      --extra-config "apiserver.service-node-port-range=1-32767" \
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

function enable_load_balancer_support
{
  minikube tunnel >/dev/null 2>&1 &
  disown
}

function taint_control_plane
{
  local role="node-role.kubernetes.io/control-plane"

  kubectl taint node \
    --overwrite \
    --selector "${role}" \
    "${role}:NoSchedule" >/dev/null
}

function annotate_k8s_object
{
  local kind="$1"
  local annotation="$2"
  local name="$3"

  kubectl annotate \
    --overwrite \
    "${kind}" \
    "${name}" \
    "${annotation}" >/dev/null
}

function get_object_by_annotation
{
  local kind="$1"
  local annotation_key="$2"
  local annotation_value="$3"

  kubectl get "${kind}" --output json |
    jq '.items[]' - |
    jq "select(.metadata.annotations.\"${annotation_key}\" == \"${annotation_value}\")" - |
    jq --raw-output '.metadata.name' -
}

function disable_default_storage_class
{
  local kind="StorageClass"
  local default_annotation="storageclass.kubernetes.io/is-default-class"

  get_object_by_annotation \
    "${kind}" \
    "${default_annotation}" \
    "true" |
    for_each annotate_k8s_object \
      "${kind}" \
      "${default_annotation}=false"
}

function disable_default_ingress_class
{
  local kind="IngressClass"
  local default_annotation="ingressclass.kubernetes.io/is-default-class"

  get_object_by_annotation \
    "${kind}" \
    "${default_annotation}" \
    "true" |
    for_each annotate_k8s_object \
      "${kind}" \
      "${default_annotation}=false"
}

function main
{
  install_root_ca_minikube
  start_minikube
  wait_for_k8s_node_ready
  taint_control_plane
  disable_default_storage_class
  disable_default_ingress_class
  enable_load_balancer_support

  log_info "Success $(basename "$0")"
}

main
