set -euo pipefail
shopt -s inherit_errexit

THIS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
cd "${THIS_SCRIPT_DIR}"

function main
{
  local primary_key_fingerprint="$1"

  gpg --keyserver keys.openpgp.org --send-keys "${primary_key_fingerprint}"
  gpg --keyserver pgp.mit.edu --send-keys "${primary_key_fingerprint}"
  gpg --keyserver keyserver.ubuntu.com --send-keys "${primary_key_fingerprint}"
}

# Entry point
main "$1"
