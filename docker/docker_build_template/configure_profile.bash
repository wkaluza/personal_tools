set -euo pipefail
shopt -s inherit_errexit

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
