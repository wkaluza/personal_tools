set -euo pipefail
if command -v shopt &>/dev/null; then
  shopt -s inherit_errexit
fi
THIS_SCRIPT_DIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"
cd "${THIS_SCRIPT_DIR}"

source "${THIS_SCRIPT_DIR}/shell_script_imports/logging.bash"
source "${THIS_SCRIPT_DIR}/shell_script_imports/common.bash"
source "${THIS_SCRIPT_DIR}/shell_script_imports/gogs_helpers.bash"

source <(cat "${THIS_SCRIPT_DIR}/local_domains.json" |
  jq '. | to_entries' - |
  jq '. | map( "\(.key)=\"\(.value)\"" )' - |
  jq --raw-output '. | .[]' - |
  sort)

function generate_flux_config
{
  local flux_git_source_url="$1"
  local manifests_path="$2"
  local flux_git_source="$3"
  local flux_secret="$4"

  local components_file="${manifests_path}/gotk-components.yaml"
  local sync_file="${manifests_path}/gotk-sync.yaml"

  mkdir --parents "${manifests_path}"

  local components="helm-controller,kustomize-controller,notification-controller,source-controller"
  local components_extra="image-automation-controller,image-reflector-controller"
  flux install \
    --components="${components}" \
    --components-extra="${components_extra}" \
    --export >"${components_file}"

  flux create source git "${flux_git_source}" \
    --branch="main" \
    --export \
    --interval="60s" \
    --secret-ref="${flux_secret}" \
    --silent \
    --url="${flux_git_source_url}" >"${sync_file}"

  flux create kustomization "${flux_kustomization}" \
    --export \
    --interval="10m" \
    --path="./${cluster_subdir_relpath}" \
    --prune="true" \
    --source="${flux_git_source}" >>"${sync_file}"

  cat <<EOF >"${manifests_path}/kustomization.yaml"
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - $(basename "${components_file}")
  - $(basename "${sync_file}")
EOF
}

function populate_infrastructure_repo
{
  local repo_name="$1"
  local username="$2"
  local auth_header="$3"

  local flux_namespace="flux-system"
  local flux_secret="flux-system"
  local flux_git_source="flux-system"
  local flux_kustomization="flux-system"

  local infra_temp_dir
  infra_temp_dir="$(mktemp -d)"
  local cluster_subdir_relpath="clusters/local_dev_pcspec"
  local manifests_root="${infra_temp_dir}/${cluster_subdir_relpath}"
  local manifests_path="${manifests_root}/${flux_namespace}"

  local git_clone_url="git@${DOMAIN_GIT_FRONTEND_df29c969}:${username}/${repo_name}.git"
  local flux_git_source_url="ssh://git@${DOMAIN_GIT_FRONTEND_df29c969}/${username}/${repo_name}.git"

  log_info "Cloning ${repo_name}..."
  git clone \
    "${git_clone_url}" \
    "${infra_temp_dir}" >/dev/null 2>&1

  pushd "${infra_temp_dir}" >/dev/null
  git commit \
    --allow-empty \
    --message "Repository root" >/dev/null
  git push >/dev/null 2>&1

  log_info "Generating flux manifests..."
  generate_flux_config \
    "${flux_git_source_url}" \
    "${manifests_path}" \
    "${flux_git_source}" \
    "${flux_secret}"

  git add .
  git commit \
    --message "Install flux" >/dev/null

  log_info "Pushing manifests..."
  git push >/dev/null 2>&1
  popd >/dev/null
}

function create_fresh_infrastructure_repo
{
  local repo_name="$1"

  local description="Infrastructure repository"

  log_info "Deleting gogs repository ${repo_name}..."
  gogs_delete_repo \
    "${DOMAIN_GIT_FRONTEND_df29c969}" \
    "${username}" \
    "${repo_name}" \
    "${auth_header}" >/dev/null 2>&1 || true

  log_info "Creating gogs repository ${repo_name}..."
  gogs_create_repo \
    "${DOMAIN_GIT_FRONTEND_df29c969}" \
    "${username}" \
    "${repo_name}" \
    "${description}" \
    "${auth_header}" >/dev/null 2>&1
}

function main
{
  local repo_name="infrastructure"
  local username="wkaluza"
  local token
  token="$(pass show "local_gogs_token_${username}")"
  local auth_header="Authorization: token ${token}"

  create_fresh_infrastructure_repo \
    "${repo_name}" \
    "${username}" \
    "${auth_header}"

  populate_infrastructure_repo \
    "${repo_name}" \
    "${username}" \
    "${auth_header}"

  log_info "Success $(basename "$0")"
}

main
