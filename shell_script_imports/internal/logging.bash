set -euo pipefail
if command -v shopt &>/dev/null; then
  shopt -s inherit_errexit
fi

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

function print_trace
{
  local func="${FUNCNAME[1]}"
  local line="${BASH_LINENO[1]}"
  local file="${BASH_SOURCE[2]}"

  local trace="Entered ${func} on line ${line} of ${file}"

  echo "[***TRACE***]: ${trace}"
}

function quiet
{
  local command="$1"
  local args=("${@:2}")

  quiet_stdout quiet_stderr ${command} "${args[@]}"
}

function quiet_unless_error
{
  local command="$1"
  local args=("${@:2}")

  local temp
  temp="$(mktemp)"

  if ! ${command} "${args[@]}" &>"${temp}"; then
    cat "${temp}"
    return 1
  fi
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
