set -euo pipefail
if command -v shopt &>/dev/null; then
  shopt -s inherit_errexit
fi
THIS_SCRIPT_DIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"
cd "${THIS_SCRIPT_DIR}"

source "${THIS_SCRIPT_DIR}/shell_script_imports/preamble.bash"

function wait_for_secret
{
  local json="$1"

  local name
  name="$(echo "${json}" |
    jq --raw-output '.metadata.name' -)"
  local namespace
  namespace="$(echo "${json}" |
    jq --raw-output '.metadata.namespace' -)"

  retry_until_success \
    "secret_exists ${namespace} ${name}" \
    secret_exists \
    "${namespace}" \
    "${name}"
}

function wait_for_sealed_secrets_sync
{
  if [[ "$(kubectl get \
    sealedsecrets \
    --all-namespaces \
    --output="json" |
    jq '.items | length' -)" != "0" ]]; then
    quiet kubectl wait \
      sealedsecret \
      --all \
      --all-namespaces \
      --for="condition=Synced" \
      --timeout="5m"
  fi
}

function install_sealed_secrets
{
  local namespace="$1"

  local manifest_path="${THIS_SCRIPT_DIR}/k8s/clusters/local/deploy/third_party/sealed_secrets.yaml"

  log_info "Applying sealed secrets manifests..."
  quiet apply_manifest_file \
    "${manifest_path}"

  log_info "Awaiting sealed secrets pod readiness..."
  quiet kubectl wait \
    --namespace="${namespace}" \
    pod \
    --all \
    --for="condition=Ready" \
    --timeout="5m"
  log_info "Sealed secrets pods ready"
}

function restart_sealed_secrets_controller
{
  local namespace="$1"

  local controller_name="sealed-secrets-controller"
  quiet kubectl scale deploy \
    --namespace "${namespace}" \
    --current-replicas 1 \
    --replicas 0 \
    "${controller_name}"

  quiet kubectl wait \
    deployment \
    "${controller_name}" \
    --namespace "${namespace}" \
    --for="condition=Available" \
    --timeout="5m"

  quiet kubectl scale deploy \
    --namespace "${namespace}" \
    --current-replicas 0 \
    --replicas 1 \
    "${controller_name}"

  quiet kubectl wait \
    deployment \
    "${controller_name}" \
    --namespace "${namespace}" \
    --for="condition=Available" \
    --timeout="5m"

  wait_for_sealed_secrets_sync
}

function seal_and_submit_secret
{
  local namespace="$1"
  local json="$2"

  echo "${json}" |
    kubeseal \
      --controller-name "sealed-secrets-controller" \
      --controller-namespace "${namespace}" |
    quiet kubectl apply --filename -
}

function create_bootstrap_helpers
{
  local bootstrap_namespace="$1"
  local sealed_secrets_namespace="$2"
  local sealed_secrets_bootstrap_cert="$3"
  local bootstrap_manifest_path="$4"

  local bootstrap_secrets_manifest
  bootstrap_secrets_manifest="$(bash \
    "${THIS_SCRIPT_DIR}/generate_cluster_startup_secrets.bash" \
    "${bootstrap_namespace}" \
    "${sealed_secrets_namespace}" \
    "git-ssh-key-bootstrap" \
    "git-gpg-key-bootstrap" \
    "${sealed_secrets_bootstrap_cert}" |
    jq --compact-output '.' -)"

  echo "${bootstrap_secrets_manifest}" |
    for_each seal_and_submit_secret \
      "${sealed_secrets_namespace}"

  echo "${bootstrap_secrets_manifest}" |
    for_each wait_for_secret

  restart_sealed_secrets_controller \
    "${sealed_secrets_namespace}"

  apply_manifest_file \
    "${bootstrap_manifest_path}"

  wait_for_reconciliation

  wait_for_sealed_secrets_sync
}

function clean_up_bootstrap_helpers
{
  local bootstrap_namespace="$1"
  local sealed_secrets_namespace="$2"
  local sealed_secrets_bootstrap_cert="$3"
  local bootstrap_manifest_path="$4"

  quiet kubectl delete \
    --filename "${bootstrap_manifest_path}" \
    --timeout="5m" \
    --wait

  quiet kubectl delete \
    sealedsecret \
    "${sealed_secrets_bootstrap_cert}" \
    --namespace "${sealed_secrets_namespace}" \
    --timeout="5m" \
    --wait

  quiet kubectl delete \
    secret \
    --all \
    --namespace "${sealed_secrets_namespace}" \
    --timeout="5m" \
    --wait

  wait_for_sealed_secrets_sync

  restart_sealed_secrets_controller \
    "${sealed_secrets_namespace}"
}

function wait_for_pod_readiness
{
  quiet kubectl wait \
    pod \
    --all \
    --all-namespaces \
    --for="condition=Ready" \
    --timeout="5m"
}

function reconcile_flux_ks
{
  local json="$1"

  local name
  name="$(echo "${json}" |
    jq --raw-output '.name')"
  local namespace
  namespace="$(echo "${json}" |
    jq --raw-output '.namespace')"

  quiet flux reconcile \
    kustomization \
    "${name}" \
    --namespace "${namespace}" \
    --timeout="5m" \
    --with-source

  quiet kubectl wait \
    kustomization \
    "${name}" \
    --for="condition=Ready" \
    --namespace "${namespace}" \
    --timeout="5m"
}

function force_full_reconciliation
{
  kubectl get \
    kustomization \
    --all-namespaces \
    --output json |
    jq '.items[]' - |
    jq --compact-output \
      '. | {name: .metadata.name, namespace: .metadata.namespace}' - |
    for_each reconcile_flux_ks
}

function secret_exists
{
  local namespace="$1"
  local secret_name="$2"

  if ! kubectl get \
    secret \
    --namespace="${namespace}" \
    --output="name" \
    "${secret_name}" |
    quiet grep -E "^secret/${secret_name}$"; then
    return 1
  fi
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

function wait_for_reconciliation
{
  log_info "Waiting for kustomizations to reconcile..."
  quiet kubectl wait \
    kustomization \
    --all \
    --all-namespaces \
    --for="condition=Ready" \
    --timeout="5m"
}

function resolve_cluster_test_ip
{
  local namespace="$1"
  local name="$2"
  local host="$3"
  local ip="$4"

  if ! kubectl_exec "${namespace}" "${name}" \
    host "${host}" |
    quiet grep "${ip}"; then
    return 1
  fi
}

function set_up_dns
{
  quiet kubectl apply \
    --filename "${THIS_SCRIPT_DIR}/k8s/clusters/local/deploy/system/dns.yaml"
}

function test_dns
{
  local namespace="cluster-dns-test"
  local name="cluster-dns-test"

  ensure_namespace_exists \
    "${namespace}"

  log_info "Setting up test pod..."
  quiet kubectl run \
    --image "private.docker.localhost/app/dns_tools:1" \
    --restart=Always \
    --namespace "${namespace}" \
    "${name}" \
    -- \
    sleep infinity

  quiet kubectl wait \
    pod \
    --namespace "${namespace}" \
    "${name}" \
    --for="condition=Ready" \
    --timeout="5m"

  log_info "Testing internal DNS..."
  retry_until_success \
    "resolve_cluster_test_ip" \
    resolve_cluster_test_ip \
    "${namespace}" \
    "${name}" \
    "${DOMAIN_INTERNAL_STARTUP_TEST_0fz3hzst}" \
    "111.222.111.222"

  log_info "Testing external DNS..."
  retry_until_success \
    "resolve_cluster_test_ip" \
    resolve_cluster_test_ip \
    "${namespace}" \
    "${name}" \
    "${DOMAIN_EXTERNAL_STARTUP_TEST_dmzrfohk}" \
    "123.132.213.231"

  log_info "Deleting test pod..."
  quiet kubectl delete \
    pod \
    --namespace "${namespace}" \
    --timeout="5m" \
    --wait \
    "${name}"

  quiet kubectl delete \
    namespace \
    --timeout="5m" \
    --wait \
    "${namespace}"
}

function wait_for_crds
{
  quiet kubectl wait \
    crd \
    --for "condition=Established" \
    --timeout="5m"
}

function apply_manifest_file
{
  local manifest_path="$1"

  if ! quiet kubectl apply \
    --filename "${manifest_path}" \
    --wait; then
    # CRDs may not have been established in time to instantiate them.
    # This is a known race condition in k8s.
    # Quick and dirty workaround: wait and retry.
    wait_for_crds

    quiet kubectl apply \
      --filename "${manifest_path}" \
      --wait
  fi
}

function install_flux
{
  local flux_namespace="$1"

  local flux_manifest_path="${THIS_SCRIPT_DIR}/k8s/clusters/local/deploy/third_party/flux.yaml"

  wait_flux_pre_check

  log_info "Applying flux manifests..."
  quiet apply_manifest_file \
    "${flux_manifest_path}"

  log_info "Awaiting flux pod readiness..."
  quiet kubectl wait \
    --namespace="${flux_namespace}" \
    pod \
    --all \
    --for="condition=Ready" \
    --timeout="5m"
  log_info "Flux pods ready"

  wait_flux_check
}

function main
{
  local flux_namespace="flux-system"
  local ingress_namespace="ingress-system"
  local sync_namespace="gitops-system"
  local sealed_secrets_namespace="sealed-secrets"
  local bootstrap_namespace="gitops-bootstrap"

  local sealed_secrets_bootstrap_cert="sealed-secrets-cert-bootstrap"
  local bootstrap_manifest_path="${THIS_SCRIPT_DIR}/k8s/clusters/local/bootstrap/bootstrap.yaml"

  ensure_namespace_exists \
    "${sync_namespace}"
  ensure_namespace_exists \
    "${ingress_namespace}"
  ensure_namespace_exists \
    "${flux_namespace}"
  ensure_namespace_exists \
    "${sealed_secrets_namespace}"
  ensure_namespace_exists \
    "${bootstrap_namespace}"

  set_up_dns
  test_dns

  install_sealed_secrets \
    "${sealed_secrets_namespace}"
  install_flux \
    "${flux_namespace}"

  create_bootstrap_helpers \
    "${bootstrap_namespace}" \
    "${sealed_secrets_namespace}" \
    "${sealed_secrets_bootstrap_cert}" \
    "${bootstrap_manifest_path}"
  clean_up_bootstrap_helpers \
    "${bootstrap_namespace}" \
    "${sealed_secrets_namespace}" \
    "${sealed_secrets_bootstrap_cert}" \
    "${bootstrap_manifest_path}"

  apply_manifest_file \
    "${THIS_SCRIPT_DIR}/k8s/clusters/local/deploy/gitops/admin.yaml"
  wait_for_reconciliation
  wait_for_pod_readiness

  force_full_reconciliation
  wait_for_reconciliation
  wait_for_pod_readiness

  log_info "Success $(basename "$0")"
}

main
