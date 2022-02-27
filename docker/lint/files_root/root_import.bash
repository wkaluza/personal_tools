set -euo pipefail

SET_UP_ENV="/etc/profile.d/wk_env.sh"

function install_basics
{
  apt-get install -y \
    curl \
    git
}

function install_jq
{
  apt-get install -y \
    jq
}

function install_golang
{
  source "${IMPORTS_DIR}/files_common/common_import.bash"

  local go_archive="go.tar.gz"
  local v="1.17.7"
  local download_url="https://dl.google.com/go/go${v}.linux-amd64.tar.gz"
  local target_dir="/usr/local"

  export GOROOT="${target_dir}/go"
  echo export GOROOT="\"${target_dir}/go\"" >>"${SET_UP_ENV}"

  export PATH="${GOROOT}/bin:${PATH}"
  echo export PATH="\"\${GOROOT}/bin:\${PATH}\"" >>"${SET_UP_ENV}"

  for d in $(ls -w1 /home/); do
    export PATH="/home/${d}/go/bin:${PATH}"
    echo export PATH="\"/home/${d}/go/bin:\${PATH}\"" >>"${SET_UP_ENV}"
  done

  curl -fsSL --output "./${go_archive}" "${download_url}"

  untar_gzip_to "./${go_archive}" "${target_dir}"
}
