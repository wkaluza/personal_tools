set -euo pipefail

function install_shfmt
{
  go install "mvdan.cc/sh/v3/cmd/shfmt@v3.4.2"
}
