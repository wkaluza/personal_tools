set -euo pipefail
if command -v shopt &>/dev/null; then
  shopt -s inherit_errexit
fi
THIS_SCRIPT_DIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"
cd "${THIS_SCRIPT_DIR}"

source "${THIS_SCRIPT_DIR}/shell_script_imports/preamble.bash"

function main
{
  log_info "Updating software packages..."

  sudo apt-get autoremove --yes >/dev/null 2>&1
  sudo apt-get update >/dev/null 2>&1
  sudo apt-get upgrade --with-new-pkgs --yes >/dev/null 2>&1
  # sudo apt-get dist-upgrade --yes
  # sudo apt-get clean

  sudo snap refresh >/dev/null 2>&1

  if test -f /var/run/reboot-required; then
    log_warning "Reboot required"
  else
    log_info "Reboot not required"
  fi

  log_info "Success $(basename "$0")"
}

# Entry point
main
