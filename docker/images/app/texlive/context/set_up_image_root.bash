set -euo pipefail
if command -v shopt &>/dev/null; then
  shopt -s inherit_errexit
fi
THIS_SCRIPT_DIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"

function install_texlive
{
  apt-get install --yes \
    texlive-full
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

  save_entrypoint \
    "${entrypoint_name}" \
    "${entrypoint_destination}" \
    "${uid}" \
    "${gid}"

  install_texlive
  install_inkscape
  install_xml_utils
  install_pdf_utils
}

main "$@"
