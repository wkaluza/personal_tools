set -euo pipefail
if command -v shopt &>/dev/null; then
  shopt -s inherit_errexit
fi
THIS_SCRIPT_DIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"

function install_basics_inner
{
  apt-get update
  apt-get install --yes \
    curl \
    git \
    make
}

function install_golang
{
  local go_archive="go.tar.gz"
  local v="1.17.5"
  local download_url="https://dl.google.com/go/go${v}.linux-amd64.tar.gz"

  local target_dir="/usr/local"
  export PATH="${PATH}:${target_dir}/go/bin"

  if test -d "${target_dir}/go"; then
    echo "golang is already installed"
    go version
  else
    curl -fsSL --output "${THIS_SCRIPT_DIR}/${go_archive}" "${download_url}"
    mv "${THIS_SCRIPT_DIR}/${go_archive}" "${target_dir}"

    pushd "${target_dir}"
    tar -xzf "${go_archive}"
    rm "${go_archive}"
    popd
  fi
}

function main
{
  local temp_dir
  temp_dir="$(mktemp -d)"

  install_basics_inner
  install_golang

  git clone \
    "https://github.com/docker/docker-credential-helpers.git" \
    "${temp_dir}"

  pushd "${temp_dir}"
  make pass
  popd

  mv \
    "${temp_dir}/bin/build/docker-credential-pass" \
    "/workspace/docker-credential-pass"
}

main
