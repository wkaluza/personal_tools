set -euo pipefail
if command -v shopt &>/dev/null; then
  shopt -s inherit_errexit
fi
THIS_SCRIPT_DIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"
cd "${THIS_SCRIPT_DIR}"

function main
{
  sudo apt-get autoremove --yes
  sudo apt-get update
  sudo apt-get upgrade --with-new-pkgs --yes
  # sudo apt-get dist-upgrade --yes
  # sudo apt-get clean

  test -f /var/run/reboot-required &&
    echo reboot required ||
    echo reboot not required
}

# Entry point
main
