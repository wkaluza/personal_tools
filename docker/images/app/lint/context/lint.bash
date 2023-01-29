set -euo pipefail
if command -v shopt &>/dev/null; then
  shopt -s inherit_errexit
fi

DIFFERENCES_DIR="$(mktemp -d)"
LOG_OUTPUT_DIR="$(mktemp -d)"

FILE_LIST="$(mktemp)"
INVALID_COMMIT="___NOT_A_VALID_COMMIT___"
COMMIT="${INVALID_COMMIT}"

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
  cat \
    <(git ls-files) \
    <(git status --porcelain | sed -E "s|^...||")
}

function _list_changed_files
{
  local commit="$1"

  cat \
    <(git diff --name-only "HEAD" "${commit}") \
    <(git status --porcelain | sed -E "s|^...||")
}

function _select_list_strategy_and_run
{
  local project_root_dir="$1"

  if is_git_repo; then
    if [[ "${COMMIT}" == "${INVALID_COMMIT}" ]]; then
      _list_versioned_files |
        prepend "${project_root_dir}/"
    else
      _list_changed_files "${COMMIT}" |
        prepend "${project_root_dir}/"
    fi
  else
    find "${project_root_dir}" \
      -type f \
      -and -not \( \
      -path "'${project_root_dir}/*___*/*'" -or \
      -path "'${project_root_dir}/.git/*'" -or \
      -path "'${project_root_dir}/.idea/*'" \)
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
    _select_list_strategy_and_run "${project_root_dir}" |
      for_each filter file_exists |
      sort |
      uniq >"${FILE_LIST}"
  fi

  cat "${FILE_LIST}"
}

function run_formatter
{
  local formatter="$1"
  local log_output_dir="$2"
  local input_file="$3"

  local scratch_file1
  scratch_file1="$(mktemp)"
  local scratch_file2
  scratch_file2="$(mktemp)"

  cat "${input_file}" >"${scratch_file1}"
  local digest1
  digest1="$(cat "${scratch_file1}" | sha256sum | cut -d' ' -f1)"

  local log_file_name
  log_file_name="$(echo -n "${input_file}" | sha256sum | cut -d' ' -f1).${formatter}"
  local log_file="${log_output_dir}/${log_file_name}"

  {
    echo ""
    echo "=== ${input_file} ==="
    echo "=== ${formatter} ==="
  } &>>"${log_file}"

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
  local log_output_dir="$2"
  local input_file="$3"

  local log_file_name
  log_file_name="$(echo -n "${input_file}" | sha256sum | cut -d' ' -f1).${analyser}"
  local log_file="${log_output_dir}/${log_file_name}"

  {
    echo ""
    echo "=== ${input_file} ==="
    echo "=== ${analyser} ==="
  } &>>"${log_file}"

  if ${analyser} \
    "${input_file}" &>>"${log_file}"; then
    rm -rf "${log_file}"
  else
    echo "=====" &>>"${log_file}"
    echo "" &>>"${log_file}"

    return 1
  fi
}

function shell_script_formatter
{
  local input_file="$1"
  local output_file="$2"

  cat "${input_file}" |
    shfmt -i 2 -fn >"${output_file}"
}

function find_and_format_shell_scripts
{
  local project_root_dir="$1"

  list_files \
    "${project_root_dir}" |
    {
      grep -E '\.sh$|\.bash$' || true
    } |
    for_each no_fail run_formatter \
      shell_script_formatter \
      "${LOG_OUTPUT_DIR}"
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

function find_and_analyse_shell_scripts
{
  local project_root_dir="$1"

  list_files \
    "${project_root_dir}" |
    {
      grep -E '\.sh$|\.bash$' || true
    } |
    for_each no_fail run_analyser \
      shell_script_analyser \
      "${LOG_OUTPUT_DIR}"
}

function json_file_formatter
{
  local input_file="$1"
  local output_file="$2"

  cat "${input_file}" |
    jq --sort-keys '.' - >"${output_file}"
}

function find_and_format_json_files
{
  local project_root_dir="$1"

  list_files \
    "${project_root_dir}" |
    {
      grep -E '\.json$' || true
    } |
    for_each no_fail run_formatter \
      json_file_formatter \
      "${LOG_OUTPUT_DIR}"
}

function k8s_yaml_kustomize
{
  local input_file="$1"
  local output_file="$2"

  local temp_dir
  temp_dir="$(mktemp -d)"
  local temp_output
  temp_output="$(mktemp)"

  local temp_file_name
  temp_file_name="$(basename "${f}")"
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
}

function single_yaml_file_deep_clean
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

function single_yaml_file_clean
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

function yaml_file_formatter
{
  local input_file="$1"
  local output_file="$2"

  # Good results, but mangles multiline strings
  single_yaml_file_deep_clean \
    "${input_file}" \
    "${output_file}"

  k8s_yaml_kustomize \
    "${input_file}" \
    "${output_file}"

  single_yaml_file_clean \
    "${input_file}" \
    "${output_file}"
}

function find_and_format_yaml_files
{
  local project_root_dir="$1"

  list_files \
    "${project_root_dir}" |
    {
      grep -E '\.yaml$|\.yml$' || true
    } |
    for_each no_fail run_formatter \
      yaml_file_formatter \
      "${LOG_OUTPUT_DIR}"
}

function remove_trailing_whitespace_formatter
{
  local input_file="$1"
  local output_file="$2"

  cat "${input_file}" |
    sed -E "s|[[:blank:]]+$||" >"${output_file}"
}

function remove_trailing_whitespace
{
  local project_root_dir="$1"

  list_files \
    "${project_root_dir}" |
    for_each no_fail run_formatter \
      remove_trailing_whitespace_formatter \
      "${LOG_OUTPUT_DIR}"
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

function ensure_trailing_newline
{
  local project_root_dir="$1"

  list_files \
    "${project_root_dir}" |
    for_each no_fail run_formatter \
      ensure_trailing_newline_formatter \
      "${LOG_OUTPUT_DIR}"
}

function remove_extra_trailing_newlines_formatter
{
  local input_file="$1"
  local output_file="$2"

  cat "${input_file}" >"${output_file}"

  local last_line
  while
    last_line="$(cat "${input_file}" | tail -n-1)"
    [[ "${last_line}" == "" ]]
  do
    cat "${input_file}" | head -n-1 >"${output_file}"
    cat "${output_file}" >"${input_file}"
  done
}

function remove_extra_trailing_newlines
{
  local project_root_dir="$1"

  list_files \
    "${project_root_dir}" |
    for_each no_fail run_formatter \
      remove_extra_trailing_newlines_formatter \
      "${LOG_OUTPUT_DIR}"
}

function remove_crlf_formatter
{
  local input_file="$1"
  local output_file="$2"

  cat "${input_file}" |
    sed -E "s|$(printf '\r')$||" >"${output_file}"
}

function remove_crlf
{
  local project_root_dir="$1"

  list_files \
    "${project_root_dir}" |
    for_each no_fail run_formatter \
      remove_crlf_formatter \
      "${LOG_OUTPUT_DIR}"
}

function main
{
  local project_root_dir
  project_root_dir="$(realpath "$1")"

  cd "${project_root_dir}"

  COMMIT="${2:-"${INVALID_COMMIT}"}"

  if [[ "${COMMIT}" != "${INVALID_COMMIT}" ]]; then
    if is_git_repo && ! quiet git rev-parse "${COMMIT}"; then
      log_error "${COMMIT} is not a valid commit"
      return 1
    fi
  fi

  if [[ "$(list_files "${project_root_dir}" | wc -l)" == "0" ]]; then
    log_info "Nothing to do."
    return 0
  fi

  log_info "Formatting..."

  remove_trailing_whitespace \
    "${project_root_dir}"

  ensure_trailing_newline \
    "${project_root_dir}"

  remove_extra_trailing_newlines \
    "${project_root_dir}"

  remove_crlf \
    "${project_root_dir}"

  find_and_format_json_files \
    "${project_root_dir}"

  find_and_format_shell_scripts \
    "${project_root_dir}"

  find_and_format_yaml_files \
    "${project_root_dir}"

  wait
  log_info "Formatting done"

  log_info "Performing static analysis..."

  find_and_analyse_shell_scripts \
    "${project_root_dir}"

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
