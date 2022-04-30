set -euo pipefail
shopt -s inherit_errexit

THIS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
cd "${THIS_SCRIPT_DIR}"

function main
{
  local root_profile="$1"

  cat <<'EOF' >>"${root_profile}"
if [[ "$(id -u)" != "0" ]]; then
  source "${HOME}/.profile"
fi
EOF
}

main "$1"
