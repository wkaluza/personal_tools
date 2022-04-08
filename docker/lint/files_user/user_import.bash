set -euo pipefail
shopt -s inherit_errexit

function install_shfmt
{
  go install "mvdan.cc/sh/v3/cmd/shfmt@v3.4.2"
}
