set -euo pipefail
if command -v shopt &>/dev/null; then
  shopt -s inherit_errexit
fi
THIS_SCRIPT_DIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"
cd "${THIS_SCRIPT_DIR}"

source "${THIS_SCRIPT_DIR}/shell_script_imports/preamble.bash"

function set_up_sealed_secrets_cert
{
  local namespace="$1"
  local secret_name="$2"
  local pass_key_id="$3"
  local pass_cert_id="$4"

  kubectl create secret \
    tls \
    "${secret_name}" \
    --cert=<(pass_show "${pass_cert_id}") \
    --key=<(pass_show "${pass_key_id}") \
    --namespace="${namespace}" \
    --dry-run="client" \
    --output="json" |
    kubectl label \
      --filename - \
      --local \
      --dry-run="client" \
      --output="json" \
      --overwrite \
      "sealedsecrets.bitnami.com/sealed-secrets-key=active"
}

function set_up_repo_access_secrets
{
  local namespace="$1"
  local k8s_secret_name="$2"

  kubectl create secret \
    generic \
    "${k8s_secret_name}" \
    --from-literal=identity="$(pass_show \
      "${PASS_SECRET_ID_GITOPS_SSH_SECRET_KEY_ADMIN_duccc5fs}")" \
    --from-literal=identity.pub="$(pass_show \
      "${PASS_SECRET_ID_GITOPS_SSH_PUBLIC_KEY_ADMIN_rclub6oc}")" \
    --from-literal=known_hosts="$(ssh_keyscan \
      "${DOMAIN_GIT_FRONTEND_df29c969}")" \
    --namespace="${namespace}" \
    --dry-run="client" \
    --output="json"
}

function set_up_git_gpg_signature_verification_secrets
{
  local namespace="$1"
  local secret_name="$2"

  local fingerprint="174C9368811039C87F0C806A896572D1E78ED6A7"

  kubectl create secret \
    generic \
    "${secret_name}" \
    --namespace="${namespace}" \
    --from-file="wkaluza="<(gpg --armor --export "${fingerprint}") \
    --dry-run="client" \
    --output="json"
}

function main
{
  local sync_namespace="${1:-"gitops-system"}"
  local sealed_secrets_namespace="${2:-"sealed-secrets"}"
  local git_ssh_key_name="${3:-"gitops-admin-gogs-ssh-key-lvnwoulc"}"
  local gpg_signing_key_name="${4:-"flux-git-gpg-sig-verification-gwnvmpi7"}"
  local sealed_secrets_cert_name="${5:-"sealed-secrets-certificate-jqweyrms"}"

  {
    set_up_repo_access_secrets \
      "${sync_namespace}" \
      "${git_ssh_key_name}"
    set_up_git_gpg_signature_verification_secrets \
      "${sync_namespace}" \
      "${gpg_signing_key_name}"
    set_up_sealed_secrets_cert \
      "${sealed_secrets_namespace}" \
      "${sealed_secrets_cert_name}" \
      "${PASS_SECRET_ID_SEALED_SECRETS_KEY_kxlsnqam}" \
      "${PASS_SECRET_ID_SEALED_SECRETS_CERTIFICATE_4edcp3cm}"
  } |
    jq '. | del(.metadata.creationTimestamp)' - |
    jq --compact-output --sort-keys '.' -
}

main "$@"
