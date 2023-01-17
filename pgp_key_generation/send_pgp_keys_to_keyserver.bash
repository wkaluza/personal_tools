set -euo pipefail
if command -v shopt &>/dev/null; then
  shopt -s inherit_errexit
fi
THIS_SCRIPT_DIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"
cd "${THIS_SCRIPT_DIR}"

function main
{
  local primary_key_fingerprint="$1"

  gpg --keyserver keys.openpgp.org --send-keys "${primary_key_fingerprint}"
  gpg --keyserver pgp.mit.edu --send-keys "${primary_key_fingerprint}"
  gpg --keyserver keyserver.ubuntu.com --send-keys "${primary_key_fingerprint}"
}

main "$1"
