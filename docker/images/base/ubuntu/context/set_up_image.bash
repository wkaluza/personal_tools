set -euo pipefail
if command -v shopt &>/dev/null; then
  shopt -s inherit_errexit
fi
THIS_SCRIPT_DIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"
cd "${THIS_SCRIPT_DIR}"

function prepare_apt
{
  apt-get update

  apt-get upgrade \
    --with-new-pkgs \
    --yes
}

function set_timezone
{
  local timezone="$1"

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

function create_user
{
  local uid="$1"
  local gid="$2"
  local username="$3"

  groupadd --gid "${gid}" "${username}"
  adduser \
    --disabled-password \
    --shell /bin/bash \
    --gecos "" \
    --uid "${uid}" \
    --gid "${gid}" \
    "${username}"
}

function main_root
{
  local uid="$1"
  local gid="$2"
  local username="$3"
  local timezone="$4"

  prepare_apt
  set_timezone \
    "${timezone}"
  create_user \
    "${uid}" \
    "${gid}" \
    "${username}"
}

function main
{
  local uid="$1"
  local gid="$2"
  local username="$3"
  local timezone="$4"

  if [[ "$(id -u)" == "0" ]]; then
    main_root \
      "${uid}" \
      "${gid}" \
      "${username}" \
      "${timezone}"
  fi
}

main "$1" "$2" "$3" "$4"
