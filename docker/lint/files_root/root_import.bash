set -euo pipefail
shopt -s inherit_errexit

SET_UP_ENV="/etc/profile.d/wk_env.sh"

function install_basics
{
  apt-get install --yes \
    curl \
    git
}

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

  cat <<EOF >>"${SET_UP_ENV}"
export GOROOT="${target_dir}/go"
export PATH="\${GOROOT}/bin:\${PATH}"
EOF

  for d in /home/*; do
    cat <<EOF >>"${SET_UP_ENV}"
export PATH="${d}/go/bin:\${PATH}"
EOF
  done

  source "${SET_UP_ENV}"

  curl -fsSL --output "./${go_archive}" "${download_url}"

  untar_gzip_to "./${go_archive}" "${target_dir}"
}
