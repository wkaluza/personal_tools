set -euo pipefail
if command -v shopt &>/dev/null; then
  shopt -s inherit_errexit
fi
THIS_SCRIPT_DIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"

function untar_gzip_to
{
  local archive
  archive="$(realpath "$1")"
  local target_dir
  target_dir="$(realpath "$2")"

  mkdir --parents "${target_dir}"

  tar \
    --directory "${target_dir}" \
    --extract \
    --file "${archive}" \
    --gzip
}

function install_jq
{
  apt-get install --yes \
    jq
}

function install_golang
{
  local go_root="$1"

  local temp_dir
  temp_dir="$(mktemp -d)"

  local go_archive="${temp_dir}/go.tar.gz"
  local v="1.18.1"
  local checksum="b3b815f47ababac13810fc6021eb73d65478e0b2db4b09d348eefad9581a2334"
  local download_url="https://dl.google.com/go/go${v}.linux-amd64.tar.gz"
  local go_destination="${go_root}"

  apt-get install --yes \
    wget >/dev/null 2>&1

  echo "Downloading ${go_archive}"
  wget \
    --output-document "${go_archive}" \
    --quiet \
    "${download_url}"

  echo "Verifying checksum (expect ${checksum})"
  sha256sum \
    --check <(
      cat <<EOF
${checksum}  ${go_archive}
EOF
    )

  echo "Decompressing to ${temp_dir}"
  untar_gzip_to \
    "${go_archive}" \
    "${temp_dir}"

  rm -rf "${go_destination}"

  local temp_go="${temp_dir}/go"
  echo "Moving ${temp_go} to ${go_destination}"
  mv \
    "${temp_go}" \
    "${go_destination}"

  rm -rf "${go_archive}"
  rm -rf "${temp_go}"
  rm -rf "${temp_dir}"
}

function install_shellcheck
{
  apt-get install --yes \
    shellcheck
}

function install_python3
{
  apt-get install --yes \
    python3-dev \
    python3-pip \
    python3-venv
}

function install_git
{
  apt-get install --yes \
    git
}

function install_cmake_format
{
  apt-get install --yes \
    cmake-format
}

function install_clang_format_15
{
  apt-get install --yes \
    clang-format-15
}

function install_nodejs
{
  apt-get install --yes \
    curl

  curl -fsSL "https://deb.nodesource.com/setup_lts.x" |
    bash -

  apt-get install --yes \
    nodejs

  npm config set ignore-scripts true --global
  corepack enable
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

function main
{
  local entrypoint_name="$1"
  local entrypoint_destination="$2"
  local uid="$3"
  local gid="$4"
  local go_root="$5"

  save_entrypoint \
    "${entrypoint_name}" \
    "${entrypoint_destination}" \
    "${uid}" \
    "${gid}"

  install_jq
  install_git
  install_golang \
    "${go_root}"
  install_shellcheck
  install_python3
  install_nodejs
  install_clang_format_15
  install_cmake_format
}

main "$@"
