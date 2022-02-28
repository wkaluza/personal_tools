set -euo pipefail

THIS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

function format_shell_scripts
{
  local f="$1"

  shfmt -i 2 -fn -w "$f" >/dev/null
}

function format_json
{
  local f="$1"

  local json_text
  json_text="$(cat "$f")"
  echo "$json_text" |
    jq --sort-keys '.' - >"$f"
}

function main
{
  local project_root_dir="$(realpath "${THIS_SCRIPT_DIR}/..")"

  for f in $(find "${project_root_dir}" \
    -type f \
    -name '*.json' \
    -and -not \( \
    -path "${project_root_dir}/*___*/*" -or \
    -path "${project_root_dir}/.git/*" -or \
    -path "${project_root_dir}/.idea/*" \)); do
    echo "$f"
    format_json "$f" &
  done

  for f in $(find "${project_root_dir}" \
    -type f \
    -name '*.bash' \
    -and -not \( \
    -path "${project_root_dir}/*___*/*" -or \
    -path "${project_root_dir}/.git/*" -or \
    -path "${project_root_dir}/.idea/*" \)); do
    echo "$f"
    format_shell_scripts "$f" &
  done

  echo Waiting...
  wait
  echo Success
}

# Entry point
main
