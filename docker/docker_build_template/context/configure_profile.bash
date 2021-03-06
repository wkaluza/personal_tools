set -euo pipefail
if command -v shopt &>/dev/null; then
  shopt -s inherit_errexit
fi
THIS_SCRIPT_DIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"
cd "${THIS_SCRIPT_DIR}"

function main
{
  local root_profile="$1"

  cat <<'EOF' >>"${root_profile}"
if [ "$(id -u)" != "0" ]; then
  source "${HOME}/.profile"
fi
EOF
}

main "$1"
