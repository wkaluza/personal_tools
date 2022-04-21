set -euo pipefail
shopt -s inherit_errexit

function configure_go
{
  cat <<'EOF' >>"${DOCKER_PROFILE}"
export PATH="${HOME}/go/bin:${PATH}"
EOF

  source "${DOCKER_PROFILE}"
}

function install_shfmt
{
  go install "mvdan.cc/sh/v3/cmd/shfmt@v3.4.2"
}
