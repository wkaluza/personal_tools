set -euo pipefail
if command -v shopt &>/dev/null; then
  shopt -s inherit_errexit
fi
THIS_SCRIPT_DIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"

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

  apt-get install --yes \
    adduser

  addgroup --gid "${gid}" "${username}"
  adduser \
    --disabled-password \
    --shell /bin/bash \
    --gecos "" \
    --uid "${uid}" \
    --gid "${gid}" \
    "${username}"
}

function update_texlive
{
  tlmgr update --self --all
}

function install_inkscape
{
  apt-get install --yes \
    inkscape \
    libcanberra-gtk-module \
    libcanberra-gtk3-module
}

function save_entrypoint
{
  local entrypoint_name="$1"
  local entrypoint_destination="$2"
  local uid="$3"
  local gid="$4"

  cp "${THIS_SCRIPT_DIR}/${entrypoint_name}" \
    "${entrypoint_destination}"
  chown \
    "${uid}:${gid}" \
    "${entrypoint_destination}"
}

function install_xml_utils
{
  apt-get install --yes \
    libxml2-utils
}

function install_pdf_utils
{
  apt-get install --yes \
    qpdf \
    pdftk
}

function main
{
  local entrypoint_name="$1"
  local entrypoint_destination="$2"
  local uid="$3"
  local gid="$4"
  local username="$5"
  local timezone="$6"

  prepare_apt
  set_timezone \
    "${timezone}"
  create_user \
    "${uid}" \
    "${gid}" \
    "${username}"

  save_entrypoint \
    "${entrypoint_name}" \
    "${entrypoint_destination}" \
    "${uid}" \
    "${gid}"

  update_texlive

  install_inkscape
  install_xml_utils
  install_pdf_utils
}

main "$@"
