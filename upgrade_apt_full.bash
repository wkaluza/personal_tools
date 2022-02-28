set -euo pipefail

function main
{
  sudo apt-get update
  sudo apt-get upgrade --with-new-pkgs --yes
  sudo apt-get dist-upgrade --yes
  sudo apt-get autoremove --yes
  sudo apt-get clean

  test -f /var/run/reboot-required &&
    echo reboot required ||
    echo reboot not required
}

# Entry point
main
