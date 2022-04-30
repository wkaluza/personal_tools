set -euo pipefail
shopt -s inherit_errexit

THIS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
cd "${THIS_SCRIPT_DIR}"

function main
{
  sudo apt-get update
  sudo apt-get upgrade --with-new-pkgs --yes
  # sudo apt-get dist-upgrade --yes
  # sudo apt-get autoremove --yes
  # sudo apt-get clean

  test -f /var/run/reboot-required &&
    echo reboot required ||
    echo reboot not required
}

# Entry point
main
