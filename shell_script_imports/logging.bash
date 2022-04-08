set -euo pipefail
shopt -s inherit_errexit

function log_info
{
  local message="$1"

  echo "INFO: $message"
}

function log_warning
{
  local message="$1"

  echo "WARNING: $message"
}

function log_error
{
  local message="$1"

  echo "ERROR: $message"
}

function print_trace
{
  local func="${FUNCNAME[1]}"
  local line="${BASH_LINENO[1]}"
  local file="${BASH_SOURCE[2]}"

  local trace="Entered ${func} on line ${line} of ${file}"

  echo "[***TRACE***]: $trace"
}
