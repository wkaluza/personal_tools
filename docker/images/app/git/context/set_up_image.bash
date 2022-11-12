set -euo pipefail
if command -v shopt &>/dev/null; then
  shopt -s inherit_errexit
fi
THIS_SCRIPT_DIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"
cd "${THIS_SCRIPT_DIR}"

function main_root
{
  apt-get install --yes \
    git \
    gpg
}

function main
{
  if [[ "$(id -u)" == "0" ]]; then
    main_root
  fi
}

main
