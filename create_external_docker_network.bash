set -euo pipefail
shopt -s inherit_errexit

THIS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
cd "${THIS_SCRIPT_DIR}"

EXTERNAL_NETWORK_NAME="local_network_95e6b7fd"

function ensure_external_network_exists
{
  if ! docker network ls --format '{{ .Name }}' |
    grep -E "^${EXTERNAL_NETWORK_NAME}$" >/dev/null; then
    docker network create \
      --driver "overlay" \
      --opt "encrypted" \
      --scope "swarm" \
      --subnet "192.168.192.0/24" \
      "${EXTERNAL_NETWORK_NAME}" >/dev/null
  fi
}

function main
{
  ensure_external_network_exists >/dev/null 2>&1

  echo -n "${EXTERNAL_NETWORK_NAME}"
}

main
