set -euo pipefail
if command -v shopt &>/dev/null; then
  shopt -s inherit_errexit
fi

function main
{
  local repo_name="$1"

  gh repo delete \
    --confirm \
    "${repo_name}"

  echo "Success $(basename "$0")"
}

main "$1"
