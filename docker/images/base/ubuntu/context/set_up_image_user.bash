set -euo pipefail
if command -v shopt &>/dev/null; then
  shopt -s inherit_errexit
fi

function main
{
  mkdir --parents \
    "${HOME}/.local/bin"
}

main
