set -euo pipefail
if command -v shopt &>/dev/null; then
  shopt -s inherit_errexit
fi
THIS_SCRIPT_DIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"
cd "${THIS_SCRIPT_DIR}"

source "${THIS_SCRIPT_DIR}/shell_script_imports/preamble.bash"

function generate_flux_config
{
  local output_dir="$1"

  mkdir --parents "${output_dir}"

  local components_file="${output_dir}/components.yaml"

  local components="helm-controller,kustomize-controller,notification-controller,source-controller"
  flux install \
    --components="${components}" \
    --export >"${components_file}"
}

function download_tekton
{
  local output_dir="$1"

  mkdir --parents "${output_dir}"

  local tekton_org_url="https://github.com/tektoncd"
  local pipeline_url="${tekton_org_url}/pipeline/releases/download"
  local triggers_url="${tekton_org_url}/triggers/releases/download"
  local pipeline_version="v0.43.0"
  local triggers_version="v0.22.0"

  wget \
    -q \
    -O "${output_dir}/pipeline.yaml" \
    "${pipeline_url}/${pipeline_version}/release.yaml"

  wget \
    -q \
    -O "${output_dir}/interceptors.yaml" \
    "${triggers_url}/${triggers_version}/interceptors.yaml"
  wget \
    -q \
    -O "${output_dir}/triggers.yaml" \
    "${triggers_url}/${triggers_version}/release.yaml"
}

function download_sealed_secrets
{
  local output_dir="$1"

  mkdir --parents "${output_dir}"

  local url="https://github.com/bitnami-labs/sealed-secrets/releases/download"
  local version="v0.19.3"

  wget \
    -q \
    -O "${output_dir}/controller_no_rbac.yaml" \
    "${url}/${version}/controller-norbac.yaml"
  wget \
    -q \
    -O "${output_dir}/controller.yaml" \
    "${url}/${version}/controller.yaml"
}

function main
{
  local infrastructure_root="${THIS_SCRIPT_DIR}/infrastructure"

  generate_flux_config \
    "${infrastructure_root}/flux"
  download_tekton \
    "${infrastructure_root}/tekton"
  download_sealed_secrets \
    "${infrastructure_root}/sealed_secrets"

  log_info "Success $(basename "$0")"
}

main
