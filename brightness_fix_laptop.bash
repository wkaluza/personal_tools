set -euo pipefail
if command -v shopt &>/dev/null; then
  shopt -s inherit_errexit
fi
THIS_SCRIPT_DIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"

source "${THIS_SCRIPT_DIR}/shell_script_imports/preamble.bash"

function _handle_brightness_changes
{
  local nvidia_backlight="/sys/class/backlight/nvidia_0"

  if ! test -d "${nvidia_backlight}"; then
    exit 1
  fi

  local output
  output="$(xrandr --query |
    grep -Ev 'disconnected' |
    grep -E 'connected' |
    cut -d' ' -f1 |
    sort |
    uniq |
    head -n+1)"

  local actual
  local maximum
  local bc_cmd
  local brightness_fraction
  while true; do
    inotifywait \
      --event modify \
      "${nvidia_backlight}/actual_brightness"

    actual="$(cat "${nvidia_backlight}/actual_brightness")"
    maximum="$(cat "${nvidia_backlight}/max_brightness")"
    bc_cmd="scale=2; ${actual} / ${maximum}"
    brightness_fraction="$(echo "${bc_cmd}" | bc -l)"

    xrandr \
      --output "${output}" \
      --brightness "${brightness_fraction}"
  done
}

function handle_brightness_changes
{
  _handle_brightness_changes &
  disown
}

function _list_script_instances
{
  local this_script_path="$1"

  pgrep -ax bash |
    no_fail grep -E "^.+ bash ${this_script_path}$" |
    cut -d' ' -f1 |
    sort -n |
    uniq
}

function kill_process
{
  local pid="$1"

  kill \
    -s "TERM" \
    "${pid}"
}

function is_not_child_process
{
  local parent="$1"
  local maybe_child="$2"

  if pgrep -P "${parent}" |
    grep -E "^${maybe_child}$" &>/dev/null; then

    return 1
  fi

  echo "${maybe_child}"
}

function pid_still_exists
{
  local pid="$1"

  if ! ps -p "${pid}" &>/dev/null; then
    return 1
  fi

  echo "${pid}"
}

function kill_old_instances
{
  local this_script_path="$1"

  local current_process="$$"

  local instances
  instances="$(_list_script_instances "${this_script_path}" |
    for_each filter is_not_child_process "${current_process}" |
    grep -Ev "^${current_process}$")"

  echo "${instances}" |
    for_each filter pid_still_exists |
    for_each kill_process
}

function main
{
  kill_old_instances "$0"
  handle_brightness_changes &>/dev/null

  log_info "Success $(basename "$0")"
}

main
