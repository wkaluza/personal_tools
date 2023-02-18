set -euo pipefail
if command -v shopt &>/dev/null; then
  shopt -s inherit_errexit
fi
THIS_SCRIPT_DIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"

source "${THIS_SCRIPT_DIR}/../../../shell_script_imports/preamble.bash"

PROJECT_ROOT_DIR="$(realpath "${THIS_SCRIPT_DIR}/../../..")"

function run_kustomize
{
  local input_dir="$1"
  local output_file="$2"

  mkdir --parents "$(dirname "${output_file}")"

  kubectl kustomize \
    --output="${output_file}" \
    --reorder=legacy \
    "${input_dir}"
}

function kustomize_directory
{
  local deploy_dir="$1"
  local input_dir="$2"

  local name
  name="$(basename "${input_dir}")"
  local parent_name
  parent_name="$(basename "$(dirname "${input_dir}")")"

  local output="${deploy_dir}/${parent_name}/${name}.yaml"
  mkdir --parents "$(dirname "${output}")"

  run_kustomize \
    "${input_dir}" \
    "${output}"
}

function main
{
  local src_dir="${THIS_SCRIPT_DIR}/src"
  local deploy_dir="${THIS_SCRIPT_DIR}/deploy"

  rm -rf "${deploy_dir}"

  log_info "Generating deployment manifests..."
  list_shallow_subdirectories 2 "${src_dir}" |
    for_each kustomize_directory "${deploy_dir}"

  list_shallow_subdirectories 1 "${deploy_dir}" |
    for_each generate_kustomization_yaml_for_directory

  log_info "Formatting..."
  quiet no_fail bash "${PROJECT_ROOT_DIR}/scripts/lint_in_docker.bash" \
    "${THIS_SCRIPT_DIR}"
  quiet_unless_error bash "${PROJECT_ROOT_DIR}/scripts/lint_in_docker.bash" \
    "${THIS_SCRIPT_DIR}"

  log_info "Checking kyverno policies..."
  find "${deploy_dir}" -type f -iname '*.yaml' |
    sort |
    while read -r manifest; do
      log_info "  - ${manifest}"

      quiet_unless_error kyverno apply \
        "${deploy_dir}/system/policy.yaml" \
        --resource "${manifest}"
    done

  log_info "Success $(basename "$0")"
}

main
