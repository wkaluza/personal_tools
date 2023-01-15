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
    --output="yaml"
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
    --output="yaml"
}

function set_up_git_gpg_signature_verification_secrets
{
  local namespace="$1"

  local fingerprint="174C9368811039C87F0C806A896572D1E78ED6A7"
  local secret_name="flux-git-gpg-sig-verification-gwnvmpi7"

  kubectl create secret generic \
    "${secret_name}" \
    --namespace="${namespace}" \
    --from-file="wkaluza="<(gpg --armor --export "${fingerprint}") \
    --dry-run="client" \
    --output="yaml"
}

function seal
{
  cat - |
    kubeseal \
      --cert <(pass_show \
        "${PASS_SECRET_ID_SEALED_SECRETS_CERTIFICATE_4edcp3cm}") \
      --format yaml \
      --scope strict |
    grep -v 'creationTimestamp: null'
}

function main
{
  local sync_namespace="gitops-system"
  local ingress_namespace="ingress-system"

  log_info "Sealing..."
  {
    set_up_webhook_secrets \
      "${sync_namespace}" | seal
    echo '---'
    set_up_git_gpg_signature_verification_secrets \
      "${sync_namespace}" | seal
    echo '---'
    set_up_tls_secrets \
      "${ingress_namespace}" | seal
  } >"${THIS_SCRIPT_DIR}/sealed_secrets.yaml"

  log_info "Formatting..."
  quiet no_fail bash "${THIS_SCRIPT_DIR}/scripts/lint_in_docker.bash"

  log_info "Success $(basename "$0")"
}

main
