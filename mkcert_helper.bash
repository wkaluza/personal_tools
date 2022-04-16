set -euo pipefail
shopt -s inherit_errexit

THIS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

function main
{
  local certs_dir="${HOME}/.certificates___"

  mkcert -install

  mkdir --parents "${certs_dir}"

  pushd "${certs_dir}" >/dev/null
  mkcert "docker.registry.local"
  popd >/dev/null
}

main
