set -euo pipefail
if command -v shopt &>/dev/null; then
  shopt -s inherit_errexit
fi
THIS_SCRIPT_DIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"

source "${THIS_SCRIPT_DIR}/shell_script_imports/preamble.bash"

EXTERNAL_NETWORK_NAME="local_network_95e6b7fd"

function ensure_external_network_exists
{
  if ! docker network ls --format '{{ .Name }}' |
    quiet grep -E "^${EXTERNAL_NETWORK_NAME}$"; then
    docker network create \
      --attachable \
      --driver "overlay" \
      --opt "encrypted" \
      --scope "swarm" \
      --subnet "192.168.192.0/24" \
      "${EXTERNAL_NETWORK_NAME}"
  fi
}

function main
{
  ensure_external_network_exists &>/dev/null

  echo -n "${EXTERNAL_NETWORK_NAME}"
}

main
