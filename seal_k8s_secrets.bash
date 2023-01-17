set -euo pipefail
if command -v shopt &>/dev/null; then
  shopt -s inherit_errexit
fi
THIS_SCRIPT_DIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"
cd "${THIS_SCRIPT_DIR}"

source "${THIS_SCRIPT_DIR}/shell_script_imports/preamble.bash"

CERTS_DIR="${HOME}/.wk_certificates___"

function set_up_webhook_secrets
{
  local namespace="$1"

  local k8s_secret_name="gogs-webhook-secret-bkrumqmp"
  local gogs_webhook_secret
  gogs_webhook_secret="$(pass_show \
    "${PASS_SECRET_ID_GOGS_WEBHOOK_SECRET_8q7aqxbl}")"

  kubectl create secret generic \
    "${k8s_secret_name}" \
    --from-literal=token="${gogs_webhook_secret}" \
    --namespace="${namespace}" \
    --dry-run="client" \
    --output="json" |
    jq --sort-keys '.' -
}

function set_up_tls_secrets
{
  local namespace="$1"

  kubectl create secret \
    tls \
    "webhooks-localhost-tls-4b9o4rmb" \
    --namespace="${namespace}" \
    --cert="${CERTS_DIR}/${DOMAIN_WEBHOOK_SINK_a8800f5b}.pem" \
    --key="${CERTS_DIR}/${DOMAIN_WEBHOOK_SINK_a8800f5b}.secret" \
    --dry-run="client" \
    --output="json" |
    jq --sort-keys '.' -
}

function seal_with_separator
{
  local cert_b64="$1"
  local secret_manifest="$2"

  seal \
    "${cert_b64}" \
    "${secret_manifest}"
  echo '---'
}

function seal
{
  local cert_b64="$1"
  local secret_manifest="$2"

  echo "${secret_manifest}" |
    kubeseal \
      --cert <(echo "${cert_b64}" | base64 -d) \
      --format yaml \
      --scope strict |
    grep -v creationTimestamp
}

function main
{
  local sync_namespace="gitops-system"
  local ingress_namespace="ingress-system"

  local output="${THIS_SCRIPT_DIR}/sealed_secrets.yaml"
  rm -rf "${output}"

  local cert_b64
  cert_b64="$(pass_show \
    "${PASS_SECRET_ID_SEALED_SECRETS_CERTIFICATE_4edcp3cm}" |
    base64)"

  log_info "Sealing..."
  {
    set_up_webhook_secrets \
      "${sync_namespace}"

    set_up_tls_secrets \
      "${ingress_namespace}"

    bash "${THIS_SCRIPT_DIR}/generate_cluster_startup_secrets.bash" \
      "${sync_namespace}"
  } |
    jq --compact-output '.' - |
    for_each seal_with_separator \
      "${cert_b64}" >"${output}"

  log_info "Formatting..."
  quiet no_fail bash "${THIS_SCRIPT_DIR}/scripts/lint_in_docker.bash"

  log_info "Output saved to ${output}"

  log_info "Success $(basename "$0")"
}

main
