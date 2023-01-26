set -euo pipefail
if command -v shopt &>/dev/null; then
  shopt -s inherit_errexit
fi
THIS_SCRIPT_DIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"

function set_up_main_script
{
  local name="$1"
  local destination="$2"

  cp "${THIS_SCRIPT_DIR}/${name}" \
    "${destination}"
}

function main
{
  local main_script_name="$1"
  local main_script_dest="$2"

  set_up_main_script \
    "${main_script_name}" \
    "${main_script_dest}"
}

main "$@"
