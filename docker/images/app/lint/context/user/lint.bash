set -euo pipefail
if command -v shopt &>/dev/null; then
  shopt -s inherit_errexit
fi

DIFFERENCES_DIR="$(mktemp -d)"
LOG_OUTPUT_DIR="$(mktemp -d)"

FILE_LIST="$(mktemp)"
INVALID_COMMIT="___NOT_A_VALID_COMMIT___"
COMMIT="${INVALID_COMMIT}"

function commit_is_valid
{
  local commit="$1"

  if git rev-parse \
    --verify \
    "${commit}^{commit}" &>/dev/null; then
    return 0
  fi

  return 1
}

function dir_is_empty
{
  local directory="$1"

  if [[ "$(ls -A "${directory}")" == "" ]]; then
    return 0
  else
    return 1
  fi
}

function quiet
{
  local command="$1"
  local args=("${@:2}")

  quiet_stdout quiet_stderr ${command} "${args[@]}"
}

function quiet_stdout
{
  local command="$1"
  local args=("${@:2}")

  ${command} "${args[@]}" >/dev/null
}

function quiet_stderr
{
  local command="$1"
  local args=("${@:2}")

  ${command} "${args[@]}" 2>/dev/null
}

function is_git_repo
{
  if git status --short &>/dev/null; then
    return 0
  else
    return 1
  fi
}

function log_info
{
  local message="$1"

  echo "INFO: ${message}"
}

function log_warning
{
  local message="$1"

  echo "WARNING: ${message}"
}

function log_error
{
  local message="$1"

  echo "ERROR: ${message}"
}

function prepend
{
  local prefix="$1"

  while read -r line; do
    echo "${prefix}${line}"
  done
}

function filter
{
  local command="$1"
  local args=("${@:2}")

  local output
  output="$(mktemp)"

  if quiet_stderr ${command} "${args[@]}" >"${output}"; then
    cat "${output}"
  fi
}

function for_each
{
  local fn="$1"
  local args=("${@:2}")

  cat - | while read -r item; do
    ${fn} "${args[@]}" "${item}"
  done
}

function no_fail
{
  local fn="$1"
  local args=("${@:2}")

  ${fn} "${args[@]}" ||
    true
}

function _list_versioned_files
{
  local project_root_dir="$1"

  cat \
    <(git ls-files |
      prepend "${project_root_dir}/") \
    <(git status --porcelain |
      sed -E "s|^...||" |
      prepend "$(git rev-parse --show-toplevel)/") |
    sort |
    uniq
}

function _list_changed_files
{
  local project_root_dir="$1"
  local commit="$2"

  cat \
    <(git diff --name-only "HEAD" "${commit}" |
      prepend "${project_root_dir}/") \
    <(git status --porcelain |
      sed -E "s|^...||" |
      prepend "$(git rev-parse --show-toplevel)/") |
    sort |
    uniq
}

function _list_all_files_non_git
{
  local project_root_dir="$1"

  find "${project_root_dir}" \
    -type f \
    -and -not \( \
    -path "${project_root_dir}/*___*" -or \
    -path "${project_root_dir}/*/.git/*" \) |
    sort |
    uniq
}

function _select_list_strategy_and_run
{
  local project_root_dir="$1"
  local commit="$2"

  if is_git_repo; then
    if commit_is_valid "${commit}"; then
      _list_changed_files \
        "${project_root_dir}" \
        "${commit}"
    else
      _list_versioned_files \
        "${project_root_dir}"
    fi
  else
    _list_all_files_non_git \
      "${project_root_dir}"
  fi
}

function file_exists
{
  local file_path="$1"

  if ! test -f "${file_path}"; then
    return 1
  fi

  echo "${file_path}"
}

function list_files
{
  local project_root_dir="$1"

  if [[ "$(cat "${FILE_LIST}" | wc -l)" == "0" ]]; then
    _select_list_strategy_and_run \
      "${project_root_dir}" \
      "${COMMIT}" |
      for_each filter file_exists |
      sort |
      uniq >"${FILE_LIST}"
  fi

  cat "${FILE_LIST}"
}

function run_formatter
{
  local formatter="$1"
  local input_file="$2"

  local scratch_file1
  scratch_file1="$(mktemp)"
  local scratch_file2
  scratch_file2="$(mktemp)"

  cat "${input_file}" >"${scratch_file1}"
  local digest1
  digest1="$(cat "${scratch_file1}" | sha256sum | cut -d' ' -f1)"

  local log_file_name
  log_file_name="$(echo -n "${input_file}" | sha256sum | cut -d' ' -f1).${formatter}"
  local log_file="${LOG_OUTPUT_DIR}/${log_file_name}"

  {
    echo ""
    echo "=== ${input_file} ==="
    echo "=== ${formatter} ==="
  } &>>"${log_file}"

  log_info "Formatting (${formatter}) ${input_file}..."
  if ${formatter} \
    "${scratch_file1}" \
    "${scratch_file2}" &>>"${log_file}"; then
    rm -rf "${log_file}"
  else
    echo "=====" &>>"${log_file}"
    echo "" &>>"${log_file}"

    return 1
  fi

  local digest2
  digest2="$(cat "${scratch_file2}" | sha256sum | cut -d' ' -f1)"

  if [[ "${digest1}" != "${digest2}" ]]; then
    cat "${scratch_file2}" >"${input_file}"

    touch "${DIFFERENCES_DIR}/${log_file_name}"

    return 1
  fi
}

function run_analyser
{
  local analyser="$1"
  local input_file="$2"

  local log_file_name
  log_file_name="$(echo -n "${input_file}" | sha256sum | cut -d' ' -f1).${analyser}"
  local log_file="${LOG_OUTPUT_DIR}/${log_file_name}"

  {
    echo ""
    echo "=== ${input_file} ==="
    echo "=== ${analyser} ==="
  } &>>"${log_file}"

  log_info "Analysing (${analyser}) ${input_file}..."
  if ${analyser} \
    "${input_file}" &>>"${log_file}"; then
    rm -rf "${log_file}"
  else
    echo "=====" &>>"${log_file}"
    echo "" &>>"${log_file}"

    return 1
  fi
}

function run_on_files
{
  local project_root_dir="$1"
  local file_selector="$2"
  local runner="$3"
  local strategy="$4"

  ${file_selector} \
    "${project_root_dir}" |
    for_each no_fail "${runner}" \
      "${strategy}"
}

function list_json_files
{
  local project_root_dir="$1"

  list_files \
    "${project_root_dir}" |
    no_fail grep -E '\.json$'
}

function list_shell_scripts
{
  local project_root_dir="$1"

  list_files \
    "${project_root_dir}" |
    no_fail grep -E '\.sh$|\.bash$'
}

function list_yaml_files
{
  local project_root_dir="$1"

  list_files \
    "${project_root_dir}" |
    no_fail grep -E '\.yaml$|\.yml$'
}

function shell_script_formatter
{
  local input_file="$1"
  local output_file="$2"

  cat "${input_file}" |
    shfmt -i 2 -fn >"${output_file}"
}

function shell_script_analyser
{
  local input_file="$1"

  local severity="style"
  # local severity="info"
  # local severity="warning"
  # local severity="error"

  shellcheck \
    --enable=all \
    --exclude="SC1090,SC1091,SC2002,SC2086,SC2154,SC2310,SC2312" \
    --severity "${severity}" \
    --shell=bash \
    "${input_file}"
}

function json_file_formatter
{
  local input_file="$1"
  local output_file="$2"

  cat "${input_file}" |
    jq --sort-keys '.' - >"${output_file}"
}

function _try_k8s_yaml_kustomize
{
  local input_file="$1"
  local output_file="$2"

  local temp_dir
  temp_dir="$(mktemp -d)"
  local temp_output
  temp_output="$(mktemp)"

  local temp_file_name
  temp_file_name="$(basename "${input_file}")"
  local temp_file="${temp_dir}/${temp_file_name}"

  cp "${input_file}" "${temp_file}"
  cat <<EOF >"${temp_dir}/kustomization.yaml"
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - ${temp_file_name}
EOF

  if kubectl kustomize \
    --output="${temp_output}" \
    --reorder=legacy \
    "${temp_dir}"; then
    cat "${temp_output}" >"${output_file}"

    return 0
  fi

  cat "${input_file}" >"${output_file}"
}

function _yaml_deep_clean
{
  local input_file="$1"
  local output_file="$2"

  cat "${input_file}" |
    yq \
      --sort-keys \
      --yaml-output \
      '.' \
      - |
    grep -Ev '^--- null$' |
    grep -Ev '^\.\.\.$' >"${output_file}"
}

function _yaml_basic_clean
{
  local input_file="$1"
  local output_file="$2"

  cat "${input_file}" |
    yq \
      --sort-keys \
      --yaml-roundtrip \
      '.' \
      - |
    grep -Ev '^--- null$' |
    grep -Ev '^\.\.\.$' >"${output_file}"
}

function yaml_formatter
{
  local input_file="$1"
  local output_file="$2"

  local intermediate_file1
  intermediate_file1="$(mktemp)"
  local intermediate_file2
  intermediate_file2="$(mktemp)"

  # Good results, but mangles multiline strings
  _yaml_deep_clean \
    "${input_file}" \
    "${intermediate_file1}"

  _try_k8s_yaml_kustomize \
    "${intermediate_file1}" \
    "${intermediate_file2}"

  _yaml_basic_clean \
    "${intermediate_file2}" \
    "${output_file}"
}

function remove_trailing_whitespace_formatter
{
  local input_file="$1"
  local output_file="$2"

  cat "${input_file}" |
    sed -E "s|[[:blank:]]+$||" >"${output_file}"
}

function ensure_trailing_newline_formatter
{
  local input_file="$1"
  local output_file="$2"

  local last_char
  last_char="$(cat "${input_file}" |
    tail -c-1)"

  local newline
  newline="$(printf '\n')"

  cat "${input_file}" >"${output_file}"

  if [[ "${last_char}" != "${newline}" ]]; then
    printf '\n' >>"${output_file}"
  fi
}

function remove_extra_trailing_newlines_formatter
{
  local input_file="$1"
  local output_file="$2"

  cat "${input_file}" >"${output_file}"

  local line_count
  local last_line
  while
    line_count="$(cat "${input_file}" | wc -l)"
    last_line="$(cat "${input_file}" | tail -n-1)"
    [[ "${line_count}" != "0" ]] && [[ "${last_line}" == "" ]]
  do
    cat "${input_file}" | head -n-1 >"${output_file}"
    cat "${output_file}" >"${input_file}"
  done
}

function remove_crlf_formatter
{
  local input_file="$1"
  local output_file="$2"

  cat "${input_file}" |
    sed -E "s|$(printf '\r')$||" >"${output_file}"
}

function main
{
  local project_root_dir
  project_root_dir="$(realpath "$1")"
  COMMIT="$2"

  cd "${project_root_dir}"

  if [[ "$(list_files "${project_root_dir}" | wc -l)" == "0" ]]; then
    log_info "Nothing to do."
    return 0
  fi

  log_info "Formatting..."

  run_on_files \
    "${project_root_dir}" \
    "list_files" \
    "run_formatter" \
    "remove_trailing_whitespace_formatter"

  run_on_files \
    "${project_root_dir}" \
    "list_files" \
    "run_formatter" \
    "ensure_trailing_newline_formatter"

  run_on_files \
    "${project_root_dir}" \
    "list_files" \
    "run_formatter" \
    "remove_extra_trailing_newlines_formatter"

  run_on_files \
    "${project_root_dir}" \
    "list_files" \
    "run_formatter" \
    "remove_crlf_formatter"

  run_on_files \
    "${project_root_dir}" \
    "list_json_files" \
    "run_formatter" \
    "json_file_formatter"

  run_on_files \
    "${project_root_dir}" \
    "list_shell_scripts" \
    "run_formatter" \
    "shell_script_formatter"

  run_on_files \
    "${project_root_dir}" \
    "list_yaml_files" \
    "run_formatter" \
    "yaml_formatter"

  wait
  log_info "Formatting done"

  log_info "Performing static analysis..."

  run_on_files \
    "${project_root_dir}" \
    "list_shell_scripts" \
    "run_analyser" \
    "shell_script_analyser"

  wait
  log_info "Static analysis done"

  if ! dir_is_empty "${LOG_OUTPUT_DIR}"; then
    cat "${LOG_OUTPUT_DIR}"/*

    log_warning "Some problems or errors were found; \
see output above for details"

    return 1
  fi

  if ! dir_is_empty "${DIFFERENCES_DIR}"; then
    log_warning "Some files were incorrectly formatted; \
re-run this script and commit the changes to the repository"

    return 1
  fi

  log_info "Success $(basename "$0")"
}

main "$1" "${2:-"${INVALID_COMMIT}"}"
