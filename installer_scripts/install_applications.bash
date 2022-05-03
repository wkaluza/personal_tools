set -euo pipefail
if command -v shopt &>/dev/null; then
  shopt -s inherit_errexit
fi
THIS_SCRIPT_DIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"
cd "${THIS_SCRIPT_DIR}"

source "${THIS_SCRIPT_DIR}/../shell_script_imports/logging.bash"
source "${THIS_SCRIPT_DIR}/../shell_script_imports/common.bash"

CHROME_DEB_PATH="does_not_exist"

function on_exit
{
  local exit_code=$?

  if [[ ${exit_code} -eq 0 ]]; then
    rm -f "${CHROME_DEB_PATH}"
  fi

  exit "${exit_code}"
}

trap on_exit EXIT

function install_basics
{
  print_trace

  sudo apt-get update
  sudo apt-get install --yes \
    curl \
    gettext-base \
    rdfind \
    vim \
    wget

  sudo apt-get install --yes \
    meld \
    vlc
}

function install_chrome
{
  print_trace

  if google-chrome --version >/dev/null; then
    log_info "Chrome is already installed"
  else
    local url="https://dl.google.com/linux/direct"

    sudo apt-get install --yes \
      fonts-liberation \
      libnspr4 \
      libnss3

    if test -x "/opt/google/chrome/google-chrome"; then
      log_info "Google Chrome already installed"
    else
      CHROME_DEB_PATH="${THIS_SCRIPT_DIR}/../chrome_$(date --utc +'%Y%m%d%H%M%S%N')___.deb"

      wget --output-document "${CHROME_DEB_PATH}" \
        "${url}/google-chrome-stable_current_amd64.deb"
      sudo dpkg --install "${CHROME_DEB_PATH}"
    fi
  fi
}

function install_brave
{
  print_trace

  if brave-browser --version >/dev/null; then
    log_info "Brave is already installed"
  else
    local key="/usr/share/keyrings/brave-browser-archive-keyring.gpg"
    local url="https://brave-browser-apt-release.s3.brave.com"

    sudo apt-get install --yes \
      apt-transport-https \
      curl

    sudo curl -fsSL -o "${key}" "${url}/brave-browser-archive-keyring.gpg"
    echo "deb [arch=$(dpkg --print-architecture) signed-by=${key}] ${url} stable main" |
      sudo tee /etc/apt/sources.list.d/brave-browser-release.list

    sudo apt-get update
    sudo apt-get install --yes \
      brave-browser
  fi
}

function install_inkscape
{
  print_trace

  sudo apt-get install --yes \
    inkscape \
    libcanberra-gtk-module \
    libcanberra-gtk3-module
}

function main
{
  ensure_not_sudo

  install_basics
  install_chrome
  install_brave
  install_inkscape

  log_info "Success: $(basename "$0")"
}

# Entry point
main
