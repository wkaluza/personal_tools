set -euo pipefail
if command -v shopt &>/dev/null; then
  shopt -s inherit_errexit
fi
THIS_SCRIPT_DIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"
cd "${THIS_SCRIPT_DIR}"

function main
{
  local repo_name="$1"

  gh repo delete \
    --confirm \
    "${repo_name}"

  echo "Success $(basename "$0")"
}

# Entry point
main "$1"
