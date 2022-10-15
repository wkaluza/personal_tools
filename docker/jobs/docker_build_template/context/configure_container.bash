set -euo pipefail
if command -v shopt &>/dev/null; then
  shopt -s inherit_errexit
fi
THIS_SCRIPT_DIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"
cd "${THIS_SCRIPT_DIR}"

function prepare_apt
{
  apt-get update

  apt-get install \
    --yes \
    apt-utils

  DEBIAN_FRONTEND="noninteractive" \
    apt-get install \
    --yes \
    keyboard-configuration

  apt-get upgrade \
    --with-new-pkgs \
    --yes
}

function set_timezone
{
  local timezone="${TZ}"

  ln \
    --force \
    --symbolic \
    "/usr/share/zoneinfo/${timezone}" \
    "/etc/localtime"
  echo "${timezone}" >"/etc/timezone"

  apt-get install \
    --yes \
    tzdata
}

function main
{
  prepare_apt
  set_timezone
}

main
