set -euo pipefail
if command -v shopt &>/dev/null; then
  shopt -s inherit_errexit
fi

function main
{
  apt-get install --yes \
    curl \
    dnsutils \
    wget
}

main
