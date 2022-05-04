set -euo pipefail
if command -v shopt &>/dev/null; then
  shopt -s inherit_errexit
fi

function install_jq
{
  apt-get install --yes \
    jq
}

function install_golang
{
  source "${IMPORTS_DIR}/files_common/common_import.bash"

  local temp_dir="${HOME}/go___deleteme"
  rm -rf "${temp_dir}"
  mkdir --parents "${temp_dir}"

  local go_archive="${temp_dir}/go.tar.gz"
  local v="1.18.1"
  local checksum="b3b815f47ababac13810fc6021eb73d65478e0b2db4b09d348eefad9581a2334"
  local download_url="https://dl.google.com/go/go${v}.linux-amd64.tar.gz"
  local go_destination="/usr/local/go"

  cat <<EOF >>"${DOCKER_PROFILE}"
export GOROOT="${go_destination}"
export PATH="\${GOROOT}/bin:\${PATH}"
EOF

  source "${DOCKER_PROFILE}"

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
