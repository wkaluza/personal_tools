set -euo pipefail
if command -v shopt &>/dev/null; then
  shopt -s inherit_errexit
fi
THIS_SCRIPT_DIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"
cd "${THIS_SCRIPT_DIR}"

source "${THIS_SCRIPT_DIR}/shell_script_imports/preamble.bash"

CERTS_DIR="${HOME}/.wk_certificates___"

function secret_exists
{
  local namespace="$1"
  local secret_name="$2"

  if ! kubectl get secret \
    --namespace="${namespace}" \
    --output="name" \
    "${secret_name}" |
    quiet grep -E "^secret/${secret_name}$"; then
    return 1
  fi
}

function set_up_secrets
{
  local sync_namespace="$1"
  local ingress_namespace="$2"

  set_up_repo_access_secrets \
    "${sync_namespace}"
  set_up_webhook_secrets \
    "${sync_namespace}"
  set_up_git_gpg_signature_verification_secrets \
    "${sync_namespace}"
  set_up_tls_secrets \
    "${ingress_namespace}"
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
  local namespace="$1"

  log_info "Waiting for kustomizations to reconcile..."
  quiet kubectl wait \
    kustomization \
    --all \
    --for="condition=Ready" \
    --namespace="${namespace}" \
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

  quiet kubectl wait pod \
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
    "${name}"

  quiet kubectl delete \
    namespace \
    "${namespace}"
}

function set_up_tls_secrets
{
  local namespace="$1"

  ensure_namespace_exists \
    "${namespace}"

  kubectl create secret \
    tls \
    "webhooks-localhost-tls-4b9o4rmb" \
    --namespace="${namespace}" \
    --cert="${CERTS_DIR}/${DOMAIN_WEBHOOK_SINK_a8800f5b}.pem" \
    --key="${CERTS_DIR}/${DOMAIN_WEBHOOK_SINK_a8800f5b}.secret" \
    --dry-run="client" \
    --output="yaml" |
    quiet kubectl apply --filename -
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

function set_up_webhook_secrets
{
  local namespace="$1"

  local k8s_secret_name="gogs-webhook-secret"
  local gogs_webhook_secret
  gogs_webhook_secret="$(pass_show \
    "${PASS_SECRET_ID_GOGS_WEBHOOK_SECRET_8q7aqxbl}")"

  kubectl create secret generic \
    "${k8s_secret_name}" \
    --from-literal=token="${gogs_webhook_secret}" \
    --dry-run="client" \
    --namespace="${namespace}" \
    --output="yaml" |
    quiet kubectl apply --filename -
}

function set_up_repo_access_secrets
{
  local namespace="$1"

  local k8s_secret_name="gitops-admin-gogs-ssh-key-lvnwoulc"

  ensure_namespace_exists \
    "${namespace}"

  kubectl create secret generic \
    "${k8s_secret_name}" \
    --from-literal=identity="$(pass_show \
      "${PASS_SECRET_ID_GITOPS_SSH_SECRET_KEY_ADMIN_duccc5fs}")" \
    --from-literal=identity.pub="$(pass_show \
      "${PASS_SECRET_ID_GITOPS_SSH_PUBLIC_KEY_ADMIN_rclub6oc}")" \
    --from-literal=known_hosts="$(ssh_keyscan \
      "${DOMAIN_GIT_FRONTEND_df29c969}")" \
    --dry-run="client" \
    --namespace="${namespace}" \
    --output="yaml" |
    quiet kubectl apply --filename -

  retry_until_success \
    "secret_exists" \
    secret_exists \
    "${namespace}" \
    "${k8s_secret_name}"
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

function set_up_git_gpg_signature_verification_secrets
{
  local namespace="$1"

  local fingerprint="174C9368811039C87F0C806A896572D1E78ED6A7"
  local secret_name="flux-git-gpg-sig-verification-gwnvmpi7"

  kubectl create secret generic \
    "${secret_name}" \
    --dry-run="client" \
    --namespace="${namespace}" \
    --output="yaml" \
    --from-file="wkaluza.${fingerprint}="<(gpg --armor --export "${fingerprint}") |
    quiet kubectl apply --filename -
}

function main
{
  local flux_namespace="flux-system"
  local ingress_namespace="ingress-system"
  local sync_namespace="gitops-system"

  ensure_namespace_exists \
    "${sync_namespace}"
  ensure_namespace_exists \
    "${ingress_namespace}"
  ensure_namespace_exists \
    "${flux_namespace}"

  set_up_dns
  test_dns

  set_up_secrets \
    "${sync_namespace}" \
    "${ingress_namespace}"

  install_flux \
    "${flux_namespace}"

  apply_manifest_file \
    "${THIS_SCRIPT_DIR}/k8s/clusters/local/deploy/gitops/admin.yaml"

  wait_for_reconciliation \
    "${sync_namespace}"

  log_info "Success $(basename "$0")"
}

main
