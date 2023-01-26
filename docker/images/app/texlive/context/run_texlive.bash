set -euo pipefail
if command -v shopt &>/dev/null; then
  shopt -s inherit_errexit
fi

function main
{
  echo "Script $(basename "$0") is a placeholder; no work done"
}

main "$@"
