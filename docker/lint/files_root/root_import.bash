set -euo pipefail
shopt -s inherit_errexit

function install_jq
{
  apt-get install --yes \
    jq
}

function install_golang
{
  source "${IMPORTS_DIR}/files_common/common_import.bash"

  local go_archive="go.tar.gz"
  local v="1.17.7"
  local download_url="https://dl.google.com/go/go${v}.linux-amd64.tar.gz"
  local target_dir="/usr/local"

  cat <<EOF >>"${DOCKER_PROFILE}"
export GOROOT="${target_dir}/go"
export PATH="\${GOROOT}/bin:\${PATH}"
EOF

  source "${DOCKER_PROFILE}"

  apt-get install --yes \
    curl

  curl -fsSL --output "./${go_archive}" "${download_url}"

  untar_gzip_to "./${go_archive}" "${target_dir}"
  rm -rf "./${go_archive}"
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
