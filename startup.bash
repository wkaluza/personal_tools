set -euo pipefail

THIS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

function main
{
  $THIS_SCRIPT_DIR/luks_mount.bash sda
  $THIS_SCRIPT_DIR/upgrade_apt_full.bash
}

main
