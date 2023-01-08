set -euo pipefail
if command -v shopt &>/dev/null; then
  shopt -s inherit_errexit
fi
THIS_SCRIPT_DIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"
cd "${THIS_SCRIPT_DIR}"

SHELL_PREAMBLE="set -euo pipefail ; shopt -s inherit_errexit"

FIND_SHELL_SCRIPTS="-name '*.bash' -or -name '*.sh'"
FIND_JSON_FILES="-name '*.json'"
FIND_YAML_FILES="-name '*.yaml' -or -name '*.yml'"

function invoke_find
{
  local project_root_dir="$1"
  local name_selector="$2"
  local fn_name="$3"

  eval find "${project_root_dir}" \
    -type f \
    -and \\\( "${name_selector}" \\\) \
    -and -not \\\( \
    -path "'${project_root_dir}/*___*/*'" -or \
    -path "'${project_root_dir}/.git/*'" -or \
    -path "'${project_root_dir}/.idea/*'" \\\) \
    -exec bash -c "'${SHELL_PREAMBLE} ; ${fn_name} \"\$1\"' -- {} \;"
}

function format_single_shell_script
{
  local f="$1"

  shfmt -i 2 -fn -w "${f}" >/dev/null
}

function find_and_format_shell_scripts
{
  local project_root_dir="$1"

  invoke_find \
    "${project_root_dir}" \
    "${FIND_SHELL_SCRIPTS}" \
    "format_single_shell_script"
}

function analyse_single_shell_script
{
  local f="$1"

  local severity="style"
  # local severity="info"
  # local severity="warning"
  # local severity="error"

  shellcheck \
    --enable=all \
    --exclude="SC1090,SC1091,SC2002,SC2086,SC2154,SC2310,SC2312" \
    --severity "${severity}" \
    --shell=bash \
    "${f}"
}

function find_and_analyse_shell_scripts
{
  local project_root_dir="$1"

  invoke_find \
    "${project_root_dir}" \
    "${FIND_SHELL_SCRIPTS}" \
    "analyse_single_shell_script"
}

function format_single_json_file
{
  local f="$1"

  local json_text
  json_text="$(cat "${f}")"
  echo "${json_text}" |
    jq --sort-keys '.' - >"${f}"
}

function find_and_format_json_files
{
  local project_root_dir="$1"

  invoke_find \
    "${project_root_dir}" \
    "${FIND_JSON_FILES}" \
    "format_single_json_file"
}

function k8s_yaml_kustomize
{
  local f="$1"

  local temp_dir
  temp_dir="$(mktemp -d)"
  local temp_output
  temp_output="$(mktemp)"

  local temp_file_name
  temp_file_name="$(basename "${f}")"
  local temp_file="${temp_dir}/${temp_file_name}"

  cp "${f}" "${temp_file}"
  cat <<EOF >"${temp_dir}/kustomization.yaml"
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - ${temp_file_name}
EOF

  if kubectl kustomize \
    --output="${temp_output}" \
    --reorder=legacy \
    "${temp_dir}" &>/dev/null; then
    cat "${temp_output}" >"${f}"

    return 0
  fi
}

function single_yaml_file_deep_clean
{
  local f="$1"

  local output
  output="$(cat "${f}" |
    yq \
      --sort-keys \
      --yaml-output \
      '.' \
      - |
    grep -Ev '^--- null$' |
    grep -Ev '^\.\.\.$')"
  echo "${output}" >"${f}"
}

function single_yaml_file_clean
{
  local f="$1"

  local output
  output="$(cat "${f}" |
    yq \
      --sort-keys \
      --yaml-roundtrip \
      '.' \
      - |
    grep -Ev '^--- null$' |
    grep -Ev '^\.\.\.$')"
  echo "${output}" >"${f}"
}

function format_single_yaml_file
{
  local f="$1"

  # Good results, but mangles multiline strings
  single_yaml_file_deep_clean "${f}"

  k8s_yaml_kustomize "${f}"

  single_yaml_file_clean "${f}"
}

function find_and_format_yaml_files
{
  local project_root_dir="$1"

  invoke_find \
    "${project_root_dir}" \
    "${FIND_YAML_FILES}" \
    "format_single_yaml_file"
}

function main
{
  local project_root_dir
  project_root_dir="$(realpath "${THIS_SCRIPT_DIR}/..")"

  export -f analyse_single_shell_script
  export -f format_single_json_file
  export -f format_single_shell_script
  export -f format_single_yaml_file
  export -f single_yaml_file_deep_clean
  export -f single_yaml_file_clean
  export -f k8s_yaml_kustomize

  echo "Formatting..."

  find_and_format_json_files \
    "${project_root_dir}"

  find_and_format_shell_scripts \
    "${project_root_dir}"

  find_and_format_yaml_files \
    "${project_root_dir}"

  wait
  echo "Formatting done"

  echo "Performing static analysis..."

  find_and_analyse_shell_scripts \
    "${project_root_dir}"

  wait
  echo "Static analysis done"

  echo "Success: $(basename "$0")"
}

# Entry point
main
