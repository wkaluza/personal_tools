set -euo pipefail
if command -v shopt &>/dev/null; then
  shopt -s inherit_errexit
fi
THIS_SCRIPT_DIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"

source "${THIS_SCRIPT_DIR}/shell_script_imports/preamble.bash"

function main
{
  log_info "Updating software packages..."

  quiet sudo apt-get autoremove --yes
  quiet sudo apt-get update
  quiet sudo apt-get upgrade --with-new-pkgs --yes
  # quiet sudo apt-get dist-upgrade --yes
  # quiet sudo apt-get clean

  quiet sudo snap refresh || true

  if test -f /var/run/reboot-required; then
    log_warning "Reboot required"
  else
    log_info "Reboot not required"
  fi

  log_info "Success $(basename "$0")"
}

main
