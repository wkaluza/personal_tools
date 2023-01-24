set -euo pipefail
if command -v shopt &>/dev/null; then
  shopt -s inherit_errexit
fi

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
