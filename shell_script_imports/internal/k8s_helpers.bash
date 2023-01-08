set -euo pipefail
if command -v shopt &>/dev/null; then
  shopt -s inherit_errexit
fi

function _list_yaml_files
{
  local dir="$1"

  find "${dir}" -iname '*.yaml' -type f
}

function _print_resource
{
  local name="$1"

  echo "  - $(basename "${name}")"
}

function generate_kustomization_yaml_for_directory
{
  local dir="$1"

  cat <<EOF >"${dir}/kustomization.yaml"
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
$(_list_yaml_files "${dir}" | sort | for_each _print_resource)
EOF
}

function kubectl_exec
{
  local namespace="$1"
  local name="$2"
  local command="$3"
  local args=("${@:4}")

  kubectl exec \
    --namespace "${namespace}" \
    "${name}" -- \
    "${command}" "${args[@]}"
}
