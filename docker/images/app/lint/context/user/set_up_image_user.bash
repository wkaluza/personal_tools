set -euo pipefail
if command -v shopt &>/dev/null; then
  shopt -s inherit_errexit
fi
THIS_SCRIPT_DIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"

function install_yq
{
  python3 -m pip install \
    yq==3.0.1
}

function install_black
{
  python3 -m pip install \
    black==23.1.0
}

function install_prettier
{
  yarn --non-interactive --silent global \
    add \
    "prettier@2.6.2"
}

function install_shfmt
{
  go install "mvdan.cc/sh/v3/cmd/shfmt@v3.4.3"
}

function install_kubectl
{
  local output_path="${HOME}/.local/bin/kubectl"
  local version="v1.25.2"
  # version="$(curl -L -s https://dl.k8s.io/release/stable.txt)"

  curl \
    --location \
    --output "${output_path}" \
    --silent \
    "https://dl.k8s.io/release/${version}/bin/linux/amd64/kubectl"

  chmod "u+x" "${output_path}"
}

function set_up_linter_script
{
  local linter_name="$1"
  local linter_dest="$2"

  cp "${THIS_SCRIPT_DIR}/${linter_name}" \
    "${linter_dest}"
}

function main
{
  local linter_name="$1"
  local linter_dest="$2"

  set_up_linter_script \
    "${linter_name}" \
    "${linter_dest}"

  install_shfmt
  install_prettier
  install_yq
  install_black
  install_kubectl
}

main "$@"
